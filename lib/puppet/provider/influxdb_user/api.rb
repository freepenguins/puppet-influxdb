# frozen_string_literal: true

require_relative '../../../puppet_x/influxdb/provider_helpers'

Puppet::Type.type(:influxdb_user).provide(:api) do
  desc 'Manages users, passwords and grants through the HTTP API.'

  include PuppetX::Influxdb::ProviderHelpers

  def user
    PuppetX::Influxdb::Api.ident(resource[:username])
  end

  def user_row
    @user_row ||= influx_rows('SHOW USERS').find { |row| row['user'] == resource[:username] }
  end

  def exists?
    !user_row.nil?
  end

  def create
    password = PuppetX::Influxdb::Api.string(resource[:password])
    if resource[:is_admin]
      influx("CREATE USER #{user} WITH PASSWORD #{password} WITH ALL PRIVILEGES")
    else
      influx("CREATE USER #{user} WITH PASSWORD #{password}")
      influx("GRANT #{resource[:privilege]} ON #{PuppetX::Influxdb::Api.ident(resource[:database])} TO #{user}")
    end
    @user_row = nil
  end

  def destroy
    influx("DROP USER #{user}")
    @user_row = nil
  end

  # InfluxDB doesn't show passwords. The getter returns the desired value,
  # and the type's insync? asks password_valid? instead of comparing.
  def password
    resource[:password]
  end

  def password_valid?
    PuppetX::Influxdb::Api.succeeds?('SHOW DATABASES', username: resource[:username], password: resource[:password], **connection)
  end

  def password=(value)
    influx("SET PASSWORD FOR #{user} = #{PuppetX::Influxdb::Api.string(value)}")
  end

  # ALL for an admin, ADMIN for an admin that should not be one, otherwise
  # the grant on the database: READ, WRITE, ALL or NONE.
  def privilege
    admin = user_row && user_row['admin']
    return(admin ? 'ALL' : 'NONE') if resource[:is_admin]
    return 'ADMIN' if admin

    grant = influx_rows("SHOW GRANTS FOR #{user}").find { |row| row['database'] == resource[:database] }
    case grant && grant['privilege']
    when 'READ' then 'READ'
    when 'WRITE' then 'WRITE'
    when 'ALL PRIVILEGES' then 'ALL'
    else 'NONE'
    end
  end

  def privilege=(value)
    if resource[:is_admin]
      influx("GRANT ALL PRIVILEGES TO #{user}")
    else
      influx("REVOKE ALL PRIVILEGES FROM #{user}") if user_row && user_row['admin']
      database = PuppetX::Influxdb::Api.ident(resource[:database])
      influx("REVOKE ALL ON #{database} FROM #{user}")
      influx("GRANT #{value} ON #{database} TO #{user}")
    end
    @user_row = nil
  end
end

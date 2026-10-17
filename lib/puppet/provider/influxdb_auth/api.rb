# frozen_string_literal: true

require_relative '../../../puppet_x/influxdb/provider_helpers'

Puppet::Type.type(:influxdb_auth).provide(:api) do
  desc 'Creates the admin user through the HTTP API.'

  include PuppetX::Influxdb::ProviderHelpers

  def exists?
    # With authentication off every login works, so the password can't be
    # checked: report the user missing and let create reset it.
    return false if auth_disabled?

    users = influx_rows('SHOW USERS')
    users.any? { |user| user['user'] == resource[:admin_username] && user['admin'] }
  rescue PuppetX::Influxdb::Api::Error
    false
  end

  def auth_disabled?
    PuppetX::Influxdb::Api.succeeds?('SHOW USERS', **connection)
  end

  def create
    user = PuppetX::Influxdb::Api.ident(resource[:admin_username])
    password = PuppetX::Influxdb::Api.string(resource[:admin_password])

    # A server with no users accepts this without credentials.
    return if PuppetX::Influxdb::Api.succeeds?("CREATE USER #{user} WITH PASSWORD #{password} WITH ALL PRIVILEGES", **connection)

    # With authentication off, anything goes: reset the password and make
    # the user an admin, whatever state it's in.
    if auth_disabled?
      existing = PuppetX::Influxdb::Api.rows('SHOW USERS', **connection).map { |u| u['user'] }
      statement = if existing.include?(resource[:admin_username])
                    "SET PASSWORD FOR #{user} = #{password}; GRANT ALL PRIVILEGES TO #{user}"
                  else
                    "CREATE USER #{user} WITH PASSWORD #{password} WITH ALL PRIVILEGES"
                  end
      PuppetX::Influxdb::Api.execute(statement, **connection)
      return
    end

    raise Puppet::Error, "InfluxDB already has users and rejected the login for '#{resource[:admin_username]}'. " \
                         'Set its password with SET PASSWORD (and GRANT ALL PRIVILEGES) as an existing admin, ' \
                         'or set http.auth-enabled to false for one Puppet run.'
  end

  def destroy
    Puppet.notice("influxdb_auth[#{resource[:name]}]: leaving the admin user in place")
  end
end

# frozen_string_literal: true

require_relative '../influxdb'

require_relative 'api'

# Methods every influxdb_* provider shares.
module PuppetX::Influxdb::ProviderHelpers
  # Runs statements as the admin user.
  def influx(statement)
    PuppetX::Influxdb::Api.execute(statement, **admin_credentials)
  end

  # Rows of a statement run as the admin user.
  def influx_rows(statement)
    PuppetX::Influxdb::Api.rows(statement, **admin_credentials)
  end

  def admin_credentials
    connection.merge(username: resource[:admin_username], password: resource[:admin_password])
  end

  # Where to connect, without credentials.
  def connection
    { port: resource[:port], ssl: resource[:ssl] }
  end

  # admin_password is a property only so Puppet can redact it.
  def admin_password
    resource[:admin_password]
  end

  def admin_password=(_value); end
end

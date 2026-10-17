# frozen_string_literal: true

require_relative '../../../puppet_x/influxdb/provider_helpers'

Puppet::Type.type(:influxdb_database).provide(:api) do
  desc 'Manages databases through the HTTP API.'

  include PuppetX::Influxdb::ProviderHelpers

  def exists?
    influx_rows('SHOW DATABASES').any? { |row| row['name'] == resource[:database] }
  end

  def create
    influx("CREATE DATABASE #{PuppetX::Influxdb::Api.ident(resource[:database])}")
  end

  def destroy
    influx("DROP DATABASE #{PuppetX::Influxdb::Api.ident(resource[:database])}")
  end
end

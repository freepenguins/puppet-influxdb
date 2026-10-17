# frozen_string_literal: true

require_relative '../../puppet_x/influxdb/type_helpers'

Puppet::Type.newtype(:influxdb_database) do
  @doc = <<-DOC
    @summary Creates or drops an InfluxDB database.
  DOC

  ensurable

  newparam(:name, namevar: true) do
    desc 'A name for the resource.'
  end

  newparam(:database) do
    desc 'The database name. Defaults to the resource name.'
    defaultto { @resource[:name] }
  end

  PuppetX::Influxdb::TypeHelpers.add_connection_attributes(self)

  autorequire(:influxdb_auth) { ['configure_auth'] }
end

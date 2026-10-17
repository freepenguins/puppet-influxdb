# frozen_string_literal: true

require_relative '../../puppet_x/influxdb/type_helpers'

Puppet::Type.newtype(:influxdb_auth) do
  @doc = <<-DOC
    @summary Makes sure InfluxDB has the admin user Puppet logs in as.

    On a server with no users yet, InfluxDB lets the first admin user be
    created without logging in, and that's how this type creates it. When
    authentication is off it creates the user, or resets its password and
    makes it an admin. When authentication is on and other users exist, it
    can't log in, so it fails with instructions.
  DOC

  ensurable do
    desc 'Only `present` does anything; `absent` leaves the user alone.'
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc 'A name for the resource.'
  end

  PuppetX::Influxdb::TypeHelpers.add_connection_attributes(self)

  validate do
    raise ArgumentError, 'admin_username is required' if self[:admin_username].to_s.empty?
    raise ArgumentError, 'admin_password is required' if self[:ensure] == :present && self[:admin_password].to_s.empty?
  end
end

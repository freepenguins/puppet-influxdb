# frozen_string_literal: true

require 'puppet/parameter/boolean'
require_relative '../../puppet_x/influxdb/type_helpers'

Puppet::Type.newtype(:influxdb_user) do
  @doc = <<-DOC
    @summary Manages an InfluxDB user, its password and its privilege.

    A non-admin user has `privilege` on `database`. An admin user has all
    privileges everywhere. InfluxDB doesn't show passwords, so Puppet checks
    the password by logging in as the user and sets it again if that fails.
  DOC

  ensurable

  newparam(:name, namevar: true) do
    desc 'A name for the resource.'
  end

  newparam(:username) do
    desc 'The user name. Defaults to the resource name.'
    defaultto { @resource[:name] }
  end

  newproperty(:password) do
    desc 'The user\'s password.'
    sensitive true

    def insync?(_is)
      provider.password_valid?
    end

    def change_to_s(_currentvalue, _newvalue)
      'changed password'
    end
  end

  newparam(:is_admin, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Whether the user is an admin.'
    defaultto :false
  end

  newproperty(:privilege) do
    desc 'The privilege on `database`: READ, WRITE or ALL. Admins are ALL.'
    validate do |value|
      raise ArgumentError, "privilege must be READ, WRITE or ALL, not #{value.inspect}" unless ['READ', 'WRITE', 'ALL'].include?(value.to_s.upcase)
    end
    munge { |value| value.to_s.upcase }
  end

  newparam(:database) do
    desc 'The database a non-admin user has `privilege` on.'
  end

  PuppetX::Influxdb::TypeHelpers.add_connection_attributes(self)

  autorequire(:influxdb_auth) { ['configure_auth'] }
  autorequire(:influxdb_database) { self[:database] ? ["influxdb_database_#{self[:database]}"] : [] }

  validate do
    next unless self[:ensure] == :present

    raise ArgumentError, 'password is required' if self[:password].nil?
    next if self[:is_admin]

    raise ArgumentError, 'a non-admin user needs privilege and database' if self[:privilege].nil? || self[:database].nil?
  end
end

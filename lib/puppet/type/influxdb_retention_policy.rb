# frozen_string_literal: true

require_relative '../../puppet_x/influxdb/type_helpers'
require_relative '../../puppet_x/influxdb/duration'

Puppet::Type.newtype(:influxdb_retention_policy) do
  @doc = <<-DOC
    @summary Manages a retention policy on an InfluxDB database.

    Durations are InfluxQL duration literals (`52w`, `365d`, `8760h0m0s`) or
    `INF`, and equal durations written differently count as the same.
  DOC

  ensurable

  newparam(:name, namevar: true) do
    desc 'A name for the resource.'
  end

  newparam(:retention_policy) do
    desc 'The policy name. Defaults to the resource name.'
    defaultto { @resource[:name] }
  end

  newparam(:database) do
    desc 'The database the policy belongs to.'
  end

  duration = Module.new do
    def self.included(property)
      property.validate do |value|
        raise ArgumentError, "#{value.inspect} is not an InfluxQL duration" unless PuppetX::Influxdb::Duration.valid?(value)
      end
    end

    def insync?(is)
      PuppetX::Influxdb::Duration.same?(is, should)
    end
  end

  newproperty(:duration) do
    desc 'How long to keep data, or INF.'
    include duration
  end

  newproperty(:shard_duration) do
    desc 'The time range each shard covers. Unmanaged when unset.'
    include duration
  end

  newproperty(:replicas) do
    desc 'The replication factor.'
    defaultto 1
    munge { |value| Integer(value) }
  end

  newproperty(:is_default) do
    desc 'Whether this is the database\'s default policy.'
    newvalues(:true, :false)
    defaultto :true

    def insync?(is)
      # InfluxDB can't un-set a default policy, only move it to another one.
      return true if should.to_s == 'false'

      is.to_s == should.to_s
    end
  end

  PuppetX::Influxdb::TypeHelpers.add_connection_attributes(self)

  autorequire(:influxdb_auth) { ['configure_auth'] }
  autorequire(:influxdb_database) { self[:database] ? ["influxdb_database_#{self[:database]}"] : [] }

  validate do
    next unless self[:ensure] == :present

    raise ArgumentError, 'database is required' if self[:database].nil?
    raise ArgumentError, 'duration is required' if self[:duration].nil?
  end
end

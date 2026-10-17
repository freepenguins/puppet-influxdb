# frozen_string_literal: true

require_relative '../../../puppet_x/influxdb/provider_helpers'

Puppet::Type.type(:influxdb_retention_policy).provide(:api) do
  desc 'Manages retention policies through the HTTP API.'

  include PuppetX::Influxdb::ProviderHelpers

  def target
    "#{PuppetX::Influxdb::Api.ident(resource[:retention_policy])} ON #{PuppetX::Influxdb::Api.ident(resource[:database])}"
  end

  def policy
    @policy ||= influx_rows("SHOW RETENTION POLICIES ON #{PuppetX::Influxdb::Api.ident(resource[:database])}")
                .find { |row| row['name'] == resource[:retention_policy] }
  rescue PuppetX::Influxdb::Api::Error => e
    # The database doesn't exist yet, so neither does the policy.
    raise unless e.message.include?('database not found')

    nil
  end

  def exists?
    !policy.nil?
  end

  def create
    statement = "CREATE RETENTION POLICY #{target} DURATION #{resource[:duration]} REPLICATION #{resource[:replicas]}"
    statement += " SHARD DURATION #{resource[:shard_duration]}" if resource[:shard_duration]
    statement += ' DEFAULT' if resource[:is_default].to_s == 'true'
    influx(statement)
    @policy = nil
  end

  def destroy
    influx("DROP RETENTION POLICY #{target}")
    @policy = nil
  end

  def duration
    policy['duration']
  end

  def duration=(value)
    influx("ALTER RETENTION POLICY #{target} DURATION #{value}")
  end

  def shard_duration
    policy['shardGroupDuration']
  end

  def shard_duration=(value)
    influx("ALTER RETENTION POLICY #{target} SHARD DURATION #{value}")
  end

  def replicas
    policy['replicaN']
  end

  def replicas=(value)
    influx("ALTER RETENTION POLICY #{target} REPLICATION #{value}")
  end

  def is_default # rubocop:disable Naming/PredicateName
    policy['default'] ? :true : :false
  end

  def is_default=(_value)
    influx("ALTER RETENTION POLICY #{target} DEFAULT")
  end
end

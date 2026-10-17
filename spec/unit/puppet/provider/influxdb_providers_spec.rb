# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/influxdb/api'

describe 'influxdb providers' do
  let(:api) { PuppetX::Influxdb::Api }
  let(:admin) { { username: 'admin', password: 'secret', port: 8086, ssl: false } }
  let(:anonymous) { { port: 8086, ssl: false } }
  let(:connection) { { admin_username: 'admin', admin_password: 'secret' } }

  def rows(*list)
    list
  end

  describe Puppet::Type.type(:influxdb_auth).provider(:api) do
    let(:resource) { Puppet::Type.type(:influxdb_auth).new(name: 'configure_auth', **connection) }
    let(:provider) { described_class.new(resource) }

    context 'with authentication on' do
      before(:each) { allow(api).to receive(:succeeds?).with('SHOW USERS', **anonymous).and_return(false) }

      it 'exists when the admin can log in and is an admin' do
        allow(api).to receive(:rows).with('SHOW USERS', **admin).and_return(rows({ 'user' => 'admin', 'admin' => true }))
        expect(provider.exists?).to be true
      end

      it 'does not exist when the login fails' do
        allow(api).to receive(:rows).with('SHOW USERS', **admin).and_raise(api::Error, 'authorization failed')
        expect(provider.exists?).to be false
      end

      it 'creates the first admin without logging in' do
        expect(api).to receive(:succeeds?).with(%(CREATE USER "admin" WITH PASSWORD 'secret' WITH ALL PRIVILEGES), **anonymous).and_return(true)
        provider.create
      end

      it 'fails with instructions when other users exist' do
        allow(api).to receive(:succeeds?).with(%r{\ACREATE USER}, **anonymous).and_return(false)
        expect { provider.create }.to raise_error(Puppet::Error, %r{already has users.*auth-enabled to false}m)
      end
    end

    context 'with authentication off' do
      before(:each) { allow(api).to receive(:succeeds?).with('SHOW USERS', **anonymous).and_return(true) }

      it 'never trusts the password' do
        expect(provider.exists?).to be false
      end

      it 'resets the password and admin rights of an existing user' do
        allow(api).to receive(:succeeds?).with(%r{\ACREATE USER}, **anonymous).and_return(false)
        allow(api).to receive(:rows).with('SHOW USERS', **anonymous).and_return(rows({ 'user' => 'admin', 'admin' => false }))
        expect(api).to receive(:execute).with(%(SET PASSWORD FOR "admin" = 'secret'; GRANT ALL PRIVILEGES TO "admin"), **anonymous)
        provider.create
      end
    end
  end

  describe Puppet::Type.type(:influxdb_database).provider(:api) do
    let(:resource) { Puppet::Type.type(:influxdb_database).new(name: 'influxdb_database_my db', database: 'my db', **connection) }
    let(:provider) { described_class.new(resource) }

    it 'finds the database' do
      allow(api).to receive(:rows).with('SHOW DATABASES', **admin).and_return(rows({ 'name' => '_internal' }, { 'name' => 'my db' }))
      expect(provider.exists?).to be true
    end

    it 'handles a server with no databases' do
      allow(api).to receive(:rows).with('SHOW DATABASES', **admin).and_return([])
      expect(provider.exists?).to be false
    end

    it 'creates and drops it, quoted' do
      expect(api).to receive(:execute).with('CREATE DATABASE "my db"', **admin)
      provider.create
      expect(api).to receive(:execute).with('DROP DATABASE "my db"', **admin)
      provider.destroy
    end
  end

  describe Puppet::Type.type(:influxdb_user).provider(:api) do
    let(:params) { { name: 'influxdb_user_grafana', username: 'grafana', password: 'pw', privilege: 'READ', database: 'telegraf' } }
    let(:resource) { Puppet::Type.type(:influxdb_user).new(**params, **connection) }
    let(:provider) { described_class.new(resource) }

    def users(admin_flag)
      allow(api).to receive(:rows).with('SHOW USERS', **admin).and_return(rows({ 'user' => 'admin', 'admin' => true }, { 'user' => 'grafana', 'admin' => admin_flag }))
    end

    it 'creates a non-admin and grants its privilege' do
      expect(api).to receive(:execute).with(%(CREATE USER "grafana" WITH PASSWORD 'pw'), **admin).ordered
      expect(api).to receive(:execute).with('GRANT READ ON "telegraf" TO "grafana"', **admin).ordered
      provider.create
    end

    it 'checks the password by logging in as the user' do
      expect(api).to receive(:succeeds?).with('SHOW DATABASES', username: 'grafana', password: 'pw', port: 8086, ssl: false).and_return(false)
      expect(provider.password_valid?).to be false
    end

    it 'sets a new password' do
      expect(api).to receive(:execute).with(%(SET PASSWORD FOR "grafana" = 'new'), **admin)
      provider.password = 'new'
    end

    it 'reads the grant on its database' do
      users(false)
      allow(api).to receive(:rows).with('SHOW GRANTS FOR "grafana"', **admin)
                                  .and_return(rows({ 'database' => 'other', 'privilege' => 'WRITE' }, { 'database' => 'telegraf', 'privilege' => 'ALL PRIVILEGES' }))
      expect(provider.privilege).to eq('ALL')
    end

    it 'reports NONE without a grant' do
      users(false)
      allow(api).to receive(:rows).with('SHOW GRANTS FOR "grafana"', **admin).and_return([])
      expect(provider.privilege).to eq('NONE')
    end

    it 'reports an admin that should not be one, and demotes it' do
      users(true)
      expect(provider.privilege).to eq('ADMIN')
      expect(api).to receive(:execute).with('REVOKE ALL PRIVILEGES FROM "grafana"', **admin).ordered
      expect(api).to receive(:execute).with('REVOKE ALL ON "telegraf" FROM "grafana"', **admin).ordered
      expect(api).to receive(:execute).with('GRANT READ ON "telegraf" TO "grafana"', **admin).ordered
      provider.privilege = 'READ'
    end

    context 'an admin' do
      let(:params) { { name: 'influxdb_user_ops', username: 'ops', password: 'pw', is_admin: true, privilege: 'ALL' } }

      it 'is created with all privileges' do
        expect(api).to receive(:execute).with(%(CREATE USER "ops" WITH PASSWORD 'pw' WITH ALL PRIVILEGES), **admin)
        provider.create
      end

      it 'is promoted when it is not an admin yet' do
        allow(api).to receive(:rows).with('SHOW USERS', **admin).and_return(rows({ 'user' => 'ops', 'admin' => false }))
        expect(provider.privilege).to eq('NONE')
        expect(api).to receive(:execute).with('GRANT ALL PRIVILEGES TO "ops"', **admin)
        provider.privilege = 'ALL'
      end
    end
  end

  describe Puppet::Type.type(:influxdb_retention_policy).provider(:api) do
    let(:params) { { name: 'rp', retention_policy: 'one_year', database: 'telegraf', duration: '52w' } }
    let(:resource) { Puppet::Type.type(:influxdb_retention_policy).new(**params, **connection) }
    let(:provider) { described_class.new(resource) }
    let(:policies) do
      rows(
        { 'name' => 'autogen', 'duration' => '0s', 'shardGroupDuration' => '168h0m0s', 'replicaN' => 1, 'default' => false },
        { 'name' => 'one_year', 'duration' => '8736h0m0s', 'shardGroupDuration' => '168h0m0s', 'replicaN' => 1, 'default' => true },
      )
    end

    it 'reads the policy' do
      allow(api).to receive(:rows).with('SHOW RETENTION POLICIES ON "telegraf"', **admin).and_return(policies)
      expect(provider.exists?).to be true
      expect(provider.duration).to eq('8736h0m0s')
      expect(provider.shard_duration).to eq('168h0m0s')
      expect(provider.replicas).to eq(1)
      expect(provider.is_default).to eq(:true)
    end

    it 'does not exist while its database does not' do
      allow(api).to receive(:rows).and_raise(api::Error, 'InfluxDB: database not found: telegraf')
      expect(provider.exists?).to be false
    end

    it 'creates it as the default' do
      expect(api).to receive(:execute).with('CREATE RETENTION POLICY "one_year" ON "telegraf" DURATION 52w REPLICATION 1 DEFAULT', **admin)
      provider.create
    end

    context 'with a shard duration, not the default' do
      let(:params) { super().merge(shard_duration: '1d', is_default: false) }

      it 'creates it with both' do
        expect(api).to receive(:execute).with('CREATE RETENTION POLICY "one_year" ON "telegraf" DURATION 52w REPLICATION 1 SHARD DURATION 1d', **admin)
        provider.create
      end
    end

    it 'alters what changed' do
      expect(api).to receive(:execute).with('ALTER RETENTION POLICY "one_year" ON "telegraf" DURATION 30d', **admin)
      provider.duration = '30d'
      expect(api).to receive(:execute).with('ALTER RETENTION POLICY "one_year" ON "telegraf" DEFAULT', **admin)
      provider.is_default = :true
    end
  end
end

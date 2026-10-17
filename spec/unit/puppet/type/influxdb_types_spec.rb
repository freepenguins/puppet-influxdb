# frozen_string_literal: true

require 'spec_helper'

describe 'influxdb types' do
  let(:connection) { { admin_username: 'admin', admin_password: 'secret' } }

  describe Puppet::Type.type(:influxdb_auth) do
    it 'defaults to present on port 8086 without HTTPS' do
      resource = described_class.new(name: 'configure_auth', **connection)
      expect(resource[:ensure]).to eq(:present)
      expect(resource[:port]).to eq(8086)
      expect(resource[:ssl]).to be false
    end

    it 'redacts the admin password' do
      resource = described_class.new(name: 'configure_auth', **connection)
      expect(resource.parameter(:admin_password).sensitive).to be true
    end

    it 'needs an admin user' do
      expect { described_class.new(name: 'configure_auth', admin_password: 'x') }.to raise_error(Puppet::ResourceError, %r{admin_username is required})
    end

    it 'rejects a bad port' do
      expect { described_class.new(name: 'configure_auth', port: 'http', **connection) }.to raise_error(Puppet::ResourceError, %r{port must be})
    end
  end

  describe Puppet::Type.type(:influxdb_database) do
    it 'uses the title as the database name' do
      expect(described_class.new(name: 'telegraf', **connection)[:database]).to eq('telegraf')
    end
  end

  describe Puppet::Type.type(:influxdb_user) do
    let(:user) { { name: 'influxdb_user_grafana', username: 'grafana', password: 'pw', **connection } }

    it 'accepts a non-admin with a privilege and a database' do
      resource = described_class.new(**user, privilege: 'read', database: 'telegraf')
      expect(resource[:privilege]).to eq('READ')
      expect(resource[:is_admin]).to be false
      expect(resource.parameter(:password).sensitive).to be true
    end

    it 'needs a privilege and a database for a non-admin' do
      expect { described_class.new(**user, privilege: 'READ') }.to raise_error(Puppet::ResourceError, %r{needs privilege and database})
    end

    it 'needs a password' do
      expect { described_class.new(name: 'x', is_admin: true, **connection) }.to raise_error(Puppet::ResourceError, %r{password is required})
    end

    it 'lets an absent user go without a password' do
      expect { described_class.new(name: 'x', ensure: 'absent', **connection) }.not_to raise_error
    end

    it 'rejects unknown privileges' do
      expect { described_class.new(**user, privilege: 'OWNER', database: 'telegraf') }.to raise_error(Puppet::ResourceError)
    end
  end

  describe Puppet::Type.type(:influxdb_retention_policy) do
    let(:policy) { { name: 'rp', retention_policy: 'one_year', database: 'telegraf', **connection } }

    it 'compares durations by length' do
      resource = described_class.new(**policy, duration: '52w')
      expect(resource.property(:duration).insync?('8736h0m0s')).to be true
      expect(resource.property(:duration).insync?('168h0m0s')).to be false
    end

    it 'rejects anything but a duration literal' do
      expect { described_class.new(**policy, duration: '52w DEFAULT') }.to raise_error(Puppet::ResourceError, %r{not an InfluxQL duration})
    end

    it 'defaults to the default policy with one replica' do
      resource = described_class.new(**policy, duration: '52w')
      expect(resource[:is_default]).to eq(:true)
      expect(resource[:replicas]).to eq(1)
    end

    it 'never tries to un-set a default policy' do
      resource = described_class.new(**policy, duration: '52w', is_default: false)
      expect(resource.property(:is_default).insync?(:true)).to be true
    end
  end
end

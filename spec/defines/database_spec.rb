# frozen_string_literal: true

require 'spec_helper'

describe 'influxdb::database' do
  let(:pre_condition) { "class { 'influxdb': admin_username => 'admin', admin_password => 'secret', api_port => 8087 }" }
  let(:title) { 'telegraf' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'creates the database as the module\'s admin user' do
        is_expected.to contain_influxdb_database('influxdb_database_telegraf').with(
          ensure: 'present',
          database: 'telegraf',
          admin_username: 'admin',
          admin_password: 'secret',
          port: 8087,
          ssl: false,
        ).that_requires('Influxdb_auth[configure_auth]')
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { is_expected.to contain_influxdb_database('influxdb_database_telegraf').with_ensure('absent') }
      end
    end
  end
end

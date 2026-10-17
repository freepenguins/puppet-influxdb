# frozen_string_literal: true

require 'spec_helper'

describe 'influxdb::user' do
  let(:pre_condition) { "class { 'influxdb': admin_username => 'admin', admin_password => 'secret' }" }
  let(:title) { 'grafana' }
  let(:facts) { on_supported_os['debian-12-x86_64'] }

  context 'a read-only user' do
    let(:params) { { password: 'pw', privilege: 'READ', database: 'telegraf' } }

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_influxdb_user('influxdb_user_grafana').with(
        ensure: 'present',
        username: 'grafana',
        password: 'pw',
        is_admin: false,
        privilege: 'READ',
        database: 'telegraf',
      ).that_requires('Influxdb_auth[configure_auth]')
    end
  end

  context 'an admin' do
    let(:params) { { password: sensitive('pw'), is_admin: true, database: 'ignored' } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_influxdb_user('influxdb_user_grafana').with(is_admin: true, privilege: 'ALL', database: nil) }
  end

  context 'without a password' do
    let(:params) { { privilege: 'READ', database: 'telegraf' } }

    it { is_expected.to compile.and_raise_error(%r{set a password}) }
  end

  context 'a non-admin without a database' do
    let(:params) { { password: 'pw', privilege: 'READ' } }

    it { is_expected.to compile.and_raise_error(%r{needs a privilege and a database}) }
  end

  context 'being removed' do
    let(:params) { { ensure: 'absent' } }

    it { is_expected.to contain_influxdb_user('influxdb_user_grafana').with_ensure('absent') }
  end
end

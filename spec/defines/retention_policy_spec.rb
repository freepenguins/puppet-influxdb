# frozen_string_literal: true

require 'spec_helper'

describe 'influxdb::retention_policy' do
  let(:pre_condition) { "class { 'influxdb': admin_username => 'admin', admin_password => 'secret' }" }
  let(:title) { 'one_year' }
  let(:facts) { on_supported_os['debian-12-x86_64'] }
  let(:params) { { database: 'telegraf', duration: '52w' } }

  it { is_expected.to compile.with_all_deps }

  it 'is the default policy, with one replica and InfluxDB\'s shard duration' do
    is_expected.to contain_influxdb_retention_policy('influxdb_rp_one_year_telegraf').with(
      ensure: 'present',
      retention_policy: 'one_year',
      database: 'telegraf',
      duration: '52w',
      shard_duration: nil,
      replicas: 1,
      is_default: true,
    ).that_requires('Influxdb_auth[configure_auth]')
  end

  context 'with a shard duration and not the default' do
    let(:params) { super().merge(shard_duration: '1d', is_default: false) }

    it { is_expected.to contain_influxdb_retention_policy('influxdb_rp_one_year_telegraf').with(shard_duration: '1d', is_default: false) }
  end

  context 'with an invalid duration' do
    let(:params) { super().merge(duration: 'a year') }

    it { is_expected.to compile.and_raise_error(%r{not an InfluxQL duration}) }
  end
end

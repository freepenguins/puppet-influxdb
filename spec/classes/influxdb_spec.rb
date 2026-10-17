# frozen_string_literal: true

require 'spec_helper'

describe 'influxdb' do
  let(:params) { { admin_username: 'admin', admin_password: 'secret' } }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:debian) { os_facts[:os]['family'] == 'Debian' }
      let(:influxdb_conf) { catalogue.resource('File', '/etc/influxdb/influxdb.conf')[:content] }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_package('influxdb').with_ensure('present') }
      it { is_expected.to contain_service('influxdb').with(ensure: 'running', enable: true) }

      it 'adds the InfluxData repository with the current signing key' do
        if debian
          is_expected.to contain_apt__source('influxdb').with(
            ensure: 'present',
            location: 'https://repos.influxdata.com/debian',
            release: 'stable',
            repos: 'main',
            key: {
              'name' => 'influxdata-archive.asc',
              'source' => 'https://repos.influxdata.com/influxdata-archive.key',
            },
          ).that_comes_before('Class[apt::update]')
          is_expected.to contain_class('apt::update').that_comes_before('Package[influxdb]')
        else
          is_expected.to contain_yumrepo('influxdb').with(
            baseurl: 'https://repos.influxdata.com/stable/$basearch/main',
            gpgkey: 'https://repos.influxdata.com/influxdata-archive.key',
            gpgcheck: '1',
          ).that_comes_before('Package[influxdb]')
        end
      end

      it 'writes influxdb.conf as TOML with authentication on' do
        is_expected.to contain_file('/etc/influxdb/influxdb.conf').with(owner: 'root', group: 'influxdb', mode: '0640')
        expect(influxdb_conf).to start_with('# This file is managed by Puppet')
        # Top-level keys come before the first table.
        expect(influxdb_conf.index('bind-address = "127.0.0.1:8088"')).to be < influxdb_conf.index('[')
        expect(influxdb_conf).to include(%([http]\n))
        expect(influxdb_conf).to include(%(auth-enabled = true\n))
        expect(influxdb_conf).to include(%(bind-address = ":8086"\n))
        expect(influxdb_conf).to include(%(wal-dir = "/var/lib/influxdb/wal"\n))
        expect(influxdb_conf).not_to include('wal_dir')
        expect(influxdb_conf).not_to include('bind-adress')
      end

      it 'creates the data directories' do
        ['/var/lib/influxdb/meta', '/var/lib/influxdb/data', '/var/lib/influxdb/wal'].each do |dir|
          is_expected.to contain_file(dir).with(ensure: 'directory', owner: 'influxdb', group: 'influxdb')
        end
      end

      it 'uses the package unit for the default config path' do
        is_expected.to contain_systemd__unit_file('influxdb.service').with_ensure('absent')
      end

      it 'restarts InfluxDB when its configuration changes' do
        is_expected.to contain_class('influxdb::config').that_notifies('Class[influxdb::service]')
      end

      it 'waits for the API, then sets up the admin user' do
        is_expected.to contain_http_conn_validator('influxdb-conn-validator').with(
          host: 'localhost', port: 8086, use_ssl: false, test_url: '/ping',
        ).that_requires('Class[influxdb::service]')
        is_expected.to contain_influxdb_auth('configure_auth').with(
          ensure: 'present', admin_username: 'admin', port: 8086, ssl: false,
        ).that_requires('Http_conn_validator[influxdb-conn-validator]')
      end

      context 'with settings merged over the defaults' do
        let(:params) do
          super().merge(
            configuration: {
              'data' => { 'dir' => '/srv/influxdb/data', 'max-series-per-database' => 0 },
              'http' => { 'log-enabled' => false },
              'udp' => [{ 'enabled' => true, 'bind-address' => ':8089', 'database' => 'udp' }],
            },
          )
        end

        it 'keeps the defaults it doesn\'t override' do
          expect(influxdb_conf).to include(%(dir = "/srv/influxdb/data"\n))
          expect(influxdb_conf).to include(%(max-series-per-database = 0\n))
          expect(influxdb_conf).to include(%(log-enabled = false\n))
          expect(influxdb_conf).to include(%(auth-enabled = true\n))
          expect(influxdb_conf).to include(%(wal-dir = "/var/lib/influxdb/wal"\n))
          expect(influxdb_conf).to include(%([[udp]]\n))
          is_expected.to contain_file('/srv/influxdb/data').with_ensure('directory')
        end
      end

      context 'with HTTPS on' do
        let(:params) { super().merge(configuration: { 'http' => { 'https-enabled' => true } }) }

        it { is_expected.to contain_http_conn_validator('influxdb-conn-validator').with_use_ssl(true) }
        it { is_expected.to contain_influxdb_auth('configure_auth').with_ssl(true) }
      end

      context 'with a Sensitive admin password' do
        let(:params) { super().merge(admin_password: sensitive('secret')) }

        it { is_expected.to compile.with_all_deps }
      end

      context 'with a config file elsewhere' do
        let(:params) { super().merge(config_path: '/srv/influxdb/influxdb.conf') }

        it 'writes its own unit to read it' do
          is_expected.to contain_systemd__unit_file('influxdb.service')
            .with_content(%r{^ExecStart=/usr/bin/influxd -config /srv/influxdb/influxdb.conf \$INFLUXD_OPTS$})
            .with_content(%r{^User=influxdb$})
            .that_notifies('Service[influxdb]')
        end
      end

      context 'without managing the repository' do
        let(:params) { super().merge(manage_repo: false) }

        it { is_expected.not_to contain_apt__source('influxdb') }
        it { is_expected.not_to contain_yumrepo('influxdb') }
      end

      context 'with databases, users and retention policies' do
        let(:params) do
          super().merge(
            databases: { 'telegraf' => {} },
            users: {
              'telegraf' => { 'password' => 'pw', 'privilege' => 'WRITE', 'database' => 'telegraf' },
            },
            retention_policies: {
              'one_year' => { 'database' => 'telegraf', 'duration' => '52w' },
            },
          )
        end

        it { is_expected.to contain_influxdb__database('telegraf') }
        it { is_expected.to contain_influxdb_database('influxdb_database_telegraf').with(database: 'telegraf', admin_username: 'admin') }
        it { is_expected.to contain_influxdb_user('influxdb_user_telegraf').with(username: 'telegraf', privilege: 'WRITE', database: 'telegraf') }
        it { is_expected.to contain_influxdb_retention_policy('influxdb_rp_one_year_telegraf').with(duration: '52w', is_default: true, replicas: 1) }
      end

      context 'with ensure => absent' do
        let(:params) { super().merge(ensure: 'absent') }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('influxdb').with_ensure('absent') }
        it { is_expected.to contain_service('influxdb').with(ensure: 'stopped', enable: false) }
        it { is_expected.to contain_file('/etc/influxdb/influxdb.conf').with_ensure('absent') }
        it { is_expected.not_to contain_influxdb_auth('configure_auth') }
        it { is_expected.not_to contain_http_conn_validator('influxdb-conn-validator') }
        it { is_expected.to contain_class('influxdb::service').that_comes_before('Class[influxdb::install]') }
      end

      context 'with a package version' do
        let(:params) { super().merge(ensure_package: '1.13.1-1') }

        it { is_expected.to contain_package('influxdb').with_ensure('1.13.1-1') }
      end
    end
  end

  context 'on an unsupported OS family' do
    let(:facts) { { os: { 'family' => 'Solaris', 'name' => 'Solaris', 'release' => { 'major' => '11' } } } }
    let(:params) { { admin_username: 'admin', admin_password: 'secret', repo_location: 'https://example.com', repo_key_source: 'https://example.com/key' } }

    it { is_expected.to compile.and_raise_error(%r{Solaris is not supported}) }
  end
end

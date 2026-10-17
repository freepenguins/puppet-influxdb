# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.1] - 2026-10-17

### Fixed
- The startup check waited for HTTP 200 from `/ping`, which answers 204, so
  every run with InfluxDB present waited 60 seconds and then failed. It now
  expects 204, and doesn't verify the certificate when HTTPS is on (it's the
  local server, often with a self-signed certificate).

## [2.0.0] - 2026-10-17

First release as `freepenguins-influxdb`, forked from
[magnuslarsen/puppet-influxdb](https://github.com/magnuslarsen/puppet-influxdb)
1.0.3. See "Upgrading from mightp-influxdb 1.x" in the README.

### Added
- Puppet 7 and 8 support, and Debian 11–13, Ubuntu 22.04/24.04, RHEL, Rocky
  and AlmaLinux 8/9.
- `manage_repo`, `repo_location`, `repo_release`, `repo_components`,
  `repo_key_name`, `repo_key_source`, `package_name`, `manage_unit_file` and
  `retention_policies` parameters on `influxdb`; `port` and `ssl` on the
  defined types.
- `Sensitive` passwords, redacted in reports and logs.
- HTTPS support for the API (`http.https-enabled`).
- Unit tests for every supported OS, the types and the providers.

### Changed
- Converted to PDK 3.4.0 with pdk-templates 3.8.0.
- InfluxData's repository now uses `influxdata-archive.key` and the
  `debian stable main` suite; `influxdb.key` has been retired.
- The configuration file is generated with `stdlib::to_toml`, so the
  Puppet Server no longer needs the `toml` gem. It is root:influxdb, 0640.
- The providers use the HTTP API instead of the `influx` CLI, so passwords
  stay out of process lists and debug logs.
- `influxdb_auth` creates the admin user only on a server with no users, and
  otherwise fails with instructions, instead of switching authentication off
  and restarting InfluxDB.
- `influxdb_user` grants and revokes privileges instead of dropping and
  recreating the user, and resets a password that no longer works.
- `influxdb_retention_policy` compares durations by length.
- The package's systemd unit is used unless `config_path` is changed.
- Dependencies: puppetlabs/stdlib 9–10, puppetlabs/apt 9.2–11, puppet/systemd
  (replacing camptocamp/systemd), puppet/healthcheck 1–2.

### Fixed
- `bind-address` (misspelt) and `reporting-disabled` were written under a
  `[global]` section that InfluxDB ignores.
- The default WAL directory was written as `wal_dir`, which InfluxDB ignores,
  so its directory resource had no path unless `wal-dir` was set by hand.
- The providers failed on a server with no databases, users or grants.
- Removing the class failed on the connection check and admin user.

### Removed
- Puppet 4–6, and CentOS 7, Oracle Linux 7, Scientific Linux 7, Debian 9 and
  Ubuntu 18.04.
- The default `[udp]` section.

## [1.0.3] - 2020-02-18
### Added
- added retention policy support.

## [1.0.2] - 2020-02-17
### Added
- added $users parameter to ::influxdb [@unki](https://github.com/unki).
- added $databases parameter to ::influxdb [@unki](https://github.com/unki).
- README: fix influxdb::user privilege-parameter [@unki](https://github.com/unki).

### Changed
- adapt reading privileges from InfluxDB grants in case of ALL-PRIVILEGES [@unki](https://github.com/unki).

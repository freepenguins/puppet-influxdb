# influxdb

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with influxdb](#setup)
    * [What influxdb affects](#what-influxdb-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with influxdb](#beginning-with-influxdb)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Upgrading from mightp-influxdb 1.x](#upgrading-from-mightp-influxdb-1x)
1. [Development - Guide for contributing to the module](#development)

## Description

This module installs [InfluxDB OSS 1.x](https://docs.influxdata.com/influxdb/v1/)
from InfluxData's package repository, writes its configuration, and manages
its databases, users and retention policies.

It is a fork of [magnuslarsen/puppet-influxdb](https://github.com/magnuslarsen/puppet-influxdb)
(`mightp-influxdb` on the Forge), updated for Puppet 7 and 8, current
InfluxData packages and the PDK. See [Upgrading](#upgrading-from-mightp-influxdb-1x)
for what changed.

## Setup

### What influxdb affects

* InfluxData's repository (`manage_repo`): on Debian and Ubuntu an APT source
  for `https://repos.influxdata.com/debian stable main` with its signing key
  in `/etc/apt/keyrings/influxdata-archive.asc`; on Red Hat and its rebuilds a
  YUM repository for `https://repos.influxdata.com/stable/$basearch/main`.
* The `influxdb` package.
* `/etc/influxdb/influxdb.conf` (root:influxdb, mode 0640), and the meta,
  data and WAL directories it names.
* The `influxdb` service. With a configuration file anywhere other than
  `/etc/influxdb/influxdb.conf`, `/etc/systemd/system/influxdb.service`
  replaces the package's unit (`manage_unit_file`).
* Inside InfluxDB: the admin user, and the databases, users and retention
  policies you declare.

### Setup requirements

* Puppet 7 or 8, with puppetlabs/stdlib 9 or later, puppetlabs/apt 9.2 or
  later, puppet/systemd and puppet/healthcheck.
* Nothing on the Puppet Server: the configuration file is generated with
  stdlib's `stdlib::to_toml`, so the `toml` gem is no longer needed.

### Beginning with influxdb

```puppet
class { 'influxdb':
  admin_username => 'admin',
  admin_password => Sensitive('change-me'),
}
```

Authentication is on (`http.auth-enabled`). On a new server InfluxDB lets the
first admin user be created without logging in, and that's how the module
creates `admin_username`. It then logs in as that user to manage everything
else.

## Usage

### Databases, users and retention policies

Declare them as parameters of the class, which is handy from Hiera:

```yaml
influxdb::admin_username: admin
influxdb::admin_password: "%{lookup('secrets::influxdb::admin')}"
influxdb::databases:
  telegraf: {}
influxdb::users:
  telegraf:
    password: "%{lookup('secrets::influxdb::telegraf')}"
    privilege: WRITE
    database: telegraf
  grafana:
    password: "%{lookup('secrets::influxdb::grafana')}"
    privilege: READ
    database: telegraf
influxdb::retention_policies:
  one_year:
    database: telegraf
    duration: 52w
```

Or as defined types:

```puppet
influxdb::database { 'metrics': }

influxdb::user { 'grafana':
  password  => Sensitive('change-me'),
  privilege => 'READ',
  database  => 'metrics',
}

influxdb::user { 'ops':
  password => Sensitive('change-me-too'),
  is_admin => true,
}

influxdb::retention_policy { 'one_year':
  database => 'metrics',
  duration => '52w',
}
```

A non-admin user has one privilege (`READ`, `WRITE` or `ALL`) on one
database. Puppet checks a user's password by logging in as that user, and sets
it again if the login fails.

Retention policy durations are InfluxQL literals (`52w`, `30d`, `1h30m`) or
`INF`. InfluxDB shows them its own way (`8736h0m0s`), but equal durations
count as the same, so `52w` doesn't cause a change on every run.

### The configuration file

`configuration` is merged over the module's defaults, which are InfluxDB's
own except that authentication is on. Your values win, and anything you
don't set keeps its default:

```puppet
class { 'influxdb':
  admin_username => 'admin',
  admin_password => Sensitive('change-me'),
  configuration  => {
    'reporting-disabled' => true,
    'data'               => {
      'dir'                     => '/srv/influxdb/data',
      'wal-dir'                 => '/srv/influxdb/wal',
      'max-series-per-database' => 0,
    },
    'http'               => {
      'log-enabled' => false,
    },
    'udp'                => [
      {
        'enabled'      => true,
        'bind-address' => ':8089',
        'database'     => 'udp',
      },
    ],
  },
}
```

* Top-level settings such as `reporting-disabled` and `bind-address` go at the
  top of the hash; sections such as `data` and `http` are nested hashes.
* `udp`, `graphite`, `collectd` and `opentsdb` can appear more than once in
  InfluxDB's configuration, so they take an array of hashes.
* If you change `http.bind-address`, set `api_port` to the same port: Puppet
  uses it to reach the API on localhost.
* With `http.https-enabled`, Puppet uses HTTPS to reach the API, without
  verifying the certificate.

### Using your own repository

```puppet
class { 'influxdb':
  admin_username => 'admin',
  admin_password => Sensitive('change-me'),
  manage_repo    => false,
}
```

Then make sure your repository provides the `influxdb` package before it's
installed, for example `Apt::Source['mine'] -> Class['influxdb']`.

### When the admin password doesn't work

If InfluxDB already has users and rejects `admin_username` with
`admin_password` (the password was changed by hand, or the server was set up
by something else), Puppet stops with an error rather than turning
authentication off behind your back. Either set the password as an existing
admin:

```
SET PASSWORD FOR "admin" = 'change-me'
GRANT ALL PRIVILEGES TO "admin"
```

or set `http.auth-enabled` to `false` in `configuration` for one Puppet run:
with authentication off the module resets the admin user's password and admin
rights, and the next run with authentication back on logs in normally.

## Reference

See [REFERENCE.md](REFERENCE.md).

## Limitations

* InfluxDB OSS 1.x only. InfluxDB 2 and 3 have a different API and
  configuration.
* Supported on Debian 11, 12 and 13, Ubuntu 22.04 and 24.04, and Red Hat
  Enterprise Linux, Rocky Linux and AlmaLinux 8 and 9, with Puppet 7 or 8.
* One InfluxDB per host, managed through its HTTP API on localhost.
* A non-admin user gets one privilege on one database.
* InfluxDB can't un-set a retention policy's default flag, so
  `is_default => false` on the current default has no effect; make another
  policy the default instead.
* `ensure => absent` removes the package, configuration file and repository,
  but leaves the data directories.

## Upgrading from mightp-influxdb 1.x

The class and defined types keep their names and parameters, so existing Hiera
data keeps working. What changed:

* **Repository:** the old module's APT source used `influxdb.key`, which
  InfluxData retired in 2023, so `apt-get update` fails on it. The APT source
  keeps its name (`influxdb`) and now uses `influxdata-archive.key` and the
  `debian stable main` suite. On Red Hat the YUM repository moves to
  `https://repos.influxdata.com/stable/$basearch/main`.
* **No `toml` gem:** the configuration is generated with `stdlib::to_toml`.
* **Configuration fixes:** `bind-address` and `reporting-disabled` are now
  top-level settings (they were written under a `[global]` section InfluxDB
  ignores, and `bind-address` was misspelt); the default WAL directory is
  written as `wal-dir` (it was `wal_dir`, which InfluxDB ignores);
  `enqueued-write-timeout` defaults to InfluxDB's `30s`; there's no default
  `[udp]` section. Write UDP listeners as `'udp' => [{ ... }]`, not
  `'[udp]' => { ... }`. The file is now root:influxdb, mode 0640.
* **Service:** the old module overwrote the package's unit in
  `/lib/systemd/system`. This version leaves the package's unit alone unless
  `config_path` is changed, and then writes an override in
  `/etc/systemd/system`. To restore the package's unit on an existing server,
  reinstall the package (`apt-get install --reinstall influxdb` or
  `dnf reinstall influxdb`).
* **Admin user:** the old `influxdb_auth` turned authentication off,
  restarted InfluxDB and recreated the admin user whenever it couldn't log in.
  This version creates the admin user only on a server without users, and
  otherwise stops with instructions (see above).
* **Providers:** they use InfluxDB's HTTP API instead of the `influx` CLI, so
  passwords no longer appear in process lists or debug logs. Passwords can be
  `Sensitive`. Changing a user's privilege grants and revokes instead of
  dropping and recreating the user, and a changed password is set again.
* **Retention policies:** durations are compared by length, so you can write
  `52w` instead of `8736h0m0s`.
* **New parameters:** `manage_repo`, the `repo_*` settings, `package_name`,
  `manage_unit_file` and `retention_policies` on the class; `port` and `ssl`
  on the defined types.
* **Removed:** Puppet 4–6, CentOS 7 and the other EOL systems; the
  camptocamp/systemd dependency (now puppet/systemd).

## Development

This is a PDK module (pdk-templates 3.8.0). Run the checks with:

```
pdk validate
pdk test unit
```

The unit tests cover every supported OS on the Puppet version you run them
with; run them with `PUPPET_GEM_VERSION='~> 7'` and `'~> 8'` to cover both.

Original module by Magnus Larsen, with contributions from
[@unki](https://github.com/unki). Licensed under Apache 2.0.

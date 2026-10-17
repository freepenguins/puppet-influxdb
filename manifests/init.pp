# @summary Installs and configures InfluxDB 1.x.
#
# Installs InfluxDB OSS 1.x from InfluxData's package repository, writes
# `influxdb.conf` from `configuration` merged over the module's defaults,
# starts the service and then creates the admin user, databases, users and
# retention policies through the `influx` CLI.
#
# Authentication is on by default (`http.auth-enabled`). On a new server
# InfluxDB lets the first admin user be created without logging in, which is
# how `admin_username` gets created. If users already exist and they don't
# include `admin_username` with `admin_password`, the run fails with a message
# instead of switching authentication off to reset it.
#
# @example A server with a database and two users
#   class { 'influxdb':
#     admin_username => 'admin',
#     admin_password => Sensitive('change-me'),
#     databases      => {
#       'telegraf' => {},
#     },
#     users          => {
#       'telegraf' => {
#         'password'  => Sensitive('telegraf-password'),
#         'privilege' => 'WRITE',
#         'database'  => 'telegraf',
#       },
#       'grafana'  => {
#         'password'  => Sensitive('grafana-password'),
#         'privilege' => 'READ',
#         'database'  => 'telegraf',
#       },
#     },
#     retention_policies => {
#       'one_year' => {
#         'database' => 'telegraf',
#         'duration' => '52w',
#       },
#     },
#   }
#
# @example Changing settings in influxdb.conf
#   class { 'influxdb':
#     admin_username => 'admin',
#     admin_password => Sensitive('change-me'),
#     configuration  => {
#       'data' => {
#         'dir'                     => '/srv/influxdb/data',
#         'wal-dir'                 => '/srv/influxdb/wal',
#         'max-series-per-database' => 0,
#       },
#     },
#   }
#
# @param admin_username
#   The InfluxDB admin user Puppet creates and then logs in as.
# @param admin_password
#   The admin user's password.
# @param ensure
#   `absent` stops InfluxDB and removes the package, configuration file and
#   (if managed) the repository. The data directories are left in place.
# @param ensure_package
#   The package's `ensure`, such as a version. Defaults to `ensure`.
# @param package_name
#   The package that provides `influxd` and `influx`.
# @param manage_repo
#   Whether to add InfluxData's repository. Set to false when the repository
#   is managed elsewhere.
# @param repo_location
#   The repository URL: the APT location on Debian and Ubuntu, the YUM base
#   URL on Red Hat and its rebuilds.
# @param repo_release
#   APT only: the release (suite) in `repo_location`.
# @param repo_components
#   APT only: the components to use from `repo_release`.
# @param repo_key_name
#   APT only: the signing key's file name in `/etc/apt/keyrings`. The `.asc`
#   extension tells APT the key is ASCII-armored.
# @param repo_key_source
#   URL of the repository's signing key.
# @param configuration
#   Settings for `influxdb.conf`, merged over the module's defaults (yours
#   win). Top-level keys are the file's sections, such as `data` and `http`;
#   `bind-address` and `reporting-disabled` go at the top level, and `udp`,
#   `graphite`, `collectd` and `opentsdb` take an array of hashes.
# @param api_port
#   The HTTP API port: used in the default `http.bind-address`, and by Puppet
#   to reach the API on localhost. If you set `http.bind-address` in
#   `configuration`, set this to the same port.
# @param config_path
#   Path of the main configuration file.
# @param owner
#   The user InfluxDB runs as, which owns its data directories.
# @param group
#   The group InfluxDB runs as.
# @param manage_unit_file
#   Whether to write `/etc/systemd/system/influxdb.service`, overriding the
#   unit the package installs. The package's unit only reads
#   `/etc/influxdb/influxdb.conf`, so this defaults to true when
#   `config_path` is anything else.
# @param databases
#   `influxdb::database` resources to declare, keyed by database name.
# @param users
#   `influxdb::user` resources to declare, keyed by user name.
# @param retention_policies
#   `influxdb::retention_policy` resources to declare, keyed by policy name.
class influxdb (
  String[1]                                $admin_username,
  Variant[String[1], Sensitive[String[1]]] $admin_password,
  # Defaults for these are in the module's Hiera data, per OS family.
  String[1]                                $repo_location,
  Stdlib::HTTPUrl                          $repo_key_source,
  Enum['present', 'absent']                $ensure              = 'present',
  Optional[String[1]]                      $ensure_package      = undef,
  String[1]                                $package_name        = 'influxdb',
  Boolean                                  $manage_repo         = true,
  Optional[String[1]]                      $repo_release        = undef,
  Array[String[1]]                         $repo_components     = [],
  Optional[String[1]]                      $repo_key_name       = undef,
  Hash                                     $configuration       = {},
  Stdlib::Port                             $api_port            = 8086,
  Stdlib::Absolutepath                     $config_path         = '/etc/influxdb/influxdb.conf',
  String[1]                                $owner               = 'influxdb',
  String[1]                                $group               = 'influxdb',
  Boolean                                  $manage_unit_file    = ($config_path != '/etc/influxdb/influxdb.conf'),
  Hash[String[1], Hash]                    $databases           = {},
  Hash[String[1], Hash]                    $users               = {},
  Hash[String[1], Hash]                    $retention_policies  = {},
) {
  $_ensure_package = pick($ensure_package, $ensure)
  # Puppet talks to the HTTP API over HTTPS when it's turned on.
  $_ssl = $configuration.dig('http', 'https-enabled') == true

  contain influxdb::install
  contain influxdb::config
  contain influxdb::service

  if                                       $ensure              == 'present' {
    Class['influxdb::install']
    -> Class['influxdb::config']
    ~> Class['influxdb::service']

    # /ping answers without credentials once the HTTP API is up.
    http_conn_validator { 'influxdb-conn-validator':
      host      => 'localhost',
      port      => $api_port,
      use_ssl   => $_ssl,
      test_url  => '/ping',
      try_sleep => 2,
      timeout   => 60,
      require   => Class['influxdb::service'],
    }

    influxdb_auth { 'configure_auth':
      ensure         => present,
      admin_username => $admin_username,
      admin_password => $admin_password,
      port           => $api_port,
      ssl            => $_ssl,
      require        => Http_conn_validator['influxdb-conn-validator'],
    }

    $databases.each |String[1] $name, Hash $params| {
      influxdb::database { $name:
        * => $params,
      }
    }
    $users.each |String[1] $name, Hash $params| {
      influxdb::user { $name:
        * => $params,
      }
    }
    $retention_policies.each |String[1] $name, Hash $params| {
      influxdb::retention_policy { $name:
        * => $params,
      }
    }
  } else {
    Class['influxdb::service']
    -> Class['influxdb::config']
    -> Class['influxdb::install']
  }
}

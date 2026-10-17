# @summary Writes influxdb.conf and creates the data directories.
#
# @api private
class influxdb::config {
  assert_private()

  if $influxdb::ensure == 'present' {
    # InfluxDB 1.x's own defaults (`influxd config`), except that
    # authentication is on.
    $default_config = {
      'reporting-disabled' => false,
      'bind-address'       => '127.0.0.1:8088',
      'meta'               => {
        'dir'                  => '/var/lib/influxdb/meta',
        'retention-autocreate' => true,
        'logging-enabled'      => true,
      },
      'data'               => {
        'dir'                                => '/var/lib/influxdb/data',
        'wal-dir'                            => '/var/lib/influxdb/wal',
        'wal-fsync-delay'                    => '0s',
        'index-version'                      => 'inmem',
        'trace-logging-enabled'              => false,
        'query-log-enabled'                  => true,
        'validate-keys'                      => false,
        'cache-max-memory-size'              => '1g',
        'cache-snapshot-memory-size'         => '25m',
        'cache-snapshot-write-cold-duration' => '10m',
        'compact-full-write-cold-duration'   => '4h',
        'max-concurrent-compactions'         => 0,
        'compact-throughput'                 => '48m',
        'compact-throughput-burst'           => '48m',
        'tsm-use-madv-willneed'              => false,
        'max-series-per-database'            => 1000000,
        'max-values-per-tag'                 => 100000,
        'max-index-log-file-size'            => '1m',
        'series-id-set-cache-size'           => 100,
      },
      'coordinator'        => {
        'write-timeout'          => '10s',
        'max-concurrent-queries' => 0,
        'query-timeout'          => '0s',
        'log-queries-after'      => '0s',
        'max-select-point'       => 0,
        'max-select-series'      => 0,
        'max-select-buckets'     => 0,
      },
      'retention'          => {
        'enabled'        => true,
        'check-interval' => '30m',
      },
      'shard-precreation'  => {
        'enabled'        => true,
        'check-interval' => '10m',
        'advance-period' => '30m',
      },
      'monitor'            => {
        'store-enabled'  => true,
        'store-database' => '_internal',
        'store-interval' => '10s',
      },
      'http'               => {
        'enabled'                    => true,
        'flux-enabled'               => false,
        'bind-address'               => ":${influxdb::api_port}",
        'auth-enabled'               => true,
        'realm'                      => 'InfluxDB',
        'log-enabled'                => true,
        'suppress-write-log'         => false,
        'access-log-path'            => '',
        'write-tracing'              => false,
        'pprof-enabled'              => true,
        'pprof-auth-enabled'         => false,
        'debug-pprof-enabled'        => false,
        'ping-auth-enabled'          => false,
        'https-enabled'              => false,
        'https-certificate'          => '/etc/ssl/influxdb.pem',
        'https-private-key'          => '',
        'shared-secret'              => '',
        'max-row-limit'              => 0,
        'max-connection-limit'       => 0,
        'unix-socket-enabled'        => false,
        'bind-socket'                => '/var/run/influxdb.sock',
        'max-body-size'              => 25000000,
        'max-concurrent-write-limit' => 0,
        'max-enqueued-write-limit'   => 0,
        'enqueued-write-timeout'     => '30s',
      },
      'logging'            => {
        'format'        => 'auto',
        'level'         => 'info',
        'suppress-logo' => false,
      },
      'subscriber'         => {
        'enabled'              => true,
        'http-timeout'         => '30s',
        'insecure-skip-verify' => false,
        'ca-certs'             => '',
        'write-concurrency'    => 40,
        'write-buffer-size'    => 1000,
      },
      'continuous_queries' => {
        'enabled'             => true,
        'log-enabled'         => true,
        'query-stats-enabled' => false,
        'run-interval'        => '1s',
      },
    }

    $config = influxdb::deep_merge($default_config, $influxdb::configuration)

    file { $influxdb::config_path:
      ensure  => file,
      owner   => 'root',
      group   => $influxdb::group,
      mode    => '0640',
      content => epp("${module_name}/influxdb.conf.epp", { 'config' => $config }),
    }

    $directories = [$config['meta']['dir'], $config['data']['dir'], $config['data']['wal-dir']].unique
    file { $directories:
      ensure => directory,
      owner  => $influxdb::owner,
      group  => $influxdb::group,
      mode   => '0755',
    }
  } else {
    file { $influxdb::config_path:
      ensure => absent,
    }
  }
}

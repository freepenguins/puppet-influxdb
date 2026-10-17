# An InfluxDB server for Telegraf, with a read-only user for Grafana.
class { 'influxdb':
  admin_username     => 'admin',
  admin_password     => Sensitive('change-me'),
  databases          => {
    'telegraf' => {},
  },
  users              => {
    'telegraf' => {
      'password'  => Sensitive('telegraf-password'),
      'privilege' => 'WRITE',
      'database'  => 'telegraf',
    },
    'grafana'  => {
      'password'  => Sensitive('grafana-password'),
      'privilege' => 'READ',
      'database'  => 'telegraf',
    },
  },
  retention_policies => {
    'one_year' => {
      'database' => 'telegraf',
      'duration' => '52w',
    },
  },
}

# @summary Creates or drops an InfluxDB database.
#
# @example
#   influxdb::database { 'telegraf': }
#
# @param ensure
#   `present` creates the database, `absent` drops it and all its data.
# @param admin_username
#   The admin user to log in as. Defaults to `influxdb::admin_username`.
# @param admin_password
#   That user's password. Defaults to `influxdb::admin_password`.
# @param port
#   The HTTP API port. Defaults to `influxdb::api_port`.
# @param ssl
#   Whether the API uses HTTPS. Defaults to `http.https-enabled` in
#   `influxdb::configuration`.
define influxdb::database (
  Enum['present', 'absent']                $ensure         = 'present',
  String[1]                                $admin_username = $influxdb::admin_username,
  Variant[String[1], Sensitive[String[1]]] $admin_password = $influxdb::admin_password,
  Stdlib::Port                             $port           = $influxdb::api_port,
  Boolean                                  $ssl            = $influxdb::_ssl,
) {
  influxdb_database { "influxdb_database_${name}":
    ensure         => $ensure,
    database       => $name,
    admin_username => $admin_username,
    admin_password => $admin_password,
    port           => $port,
    ssl            => $ssl,
    require        => Influxdb_auth['configure_auth'],
  }
}

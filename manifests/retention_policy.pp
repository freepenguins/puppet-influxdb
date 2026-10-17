# @summary Manages a retention policy on an InfluxDB database.
#
# Durations are InfluxQL duration literals, such as `52w`, `365d` or
# `8760h0m0s`, or `INF` to keep data forever. Equal durations written
# differently (`52w` and `8736h0m0s`) count as the same.
#
# @example Keep a year of data, as the database's default policy
#   influxdb::retention_policy { 'one_year':
#     database => 'telegraf',
#     duration => '52w',
#   }
#
# @param database
#   The database the policy belongs to.
# @param duration
#   How long to keep data.
# @param ensure
#   Create or drop the policy.
# @param shard_duration
#   The time range each shard covers. Leave undef to let InfluxDB pick it from
#   `duration`, and to leave it alone afterwards.
# @param replicas
#   The replication factor. Open-source InfluxDB runs one node, so this is 1.
# @param is_default
#   Whether this is the database's default policy. Setting it to false on the
#   current default has no effect: make another policy the default instead.
# @param admin_username
#   The admin user to log in as. Defaults to `influxdb::admin_username`.
# @param admin_password
#   That user's password. Defaults to `influxdb::admin_password`.
# @param port
#   The HTTP API port. Defaults to `influxdb::api_port`.
# @param ssl
#   Whether the API uses HTTPS. Defaults to `http.https-enabled` in
#   `influxdb::configuration`.
define influxdb::retention_policy (
  String[1]                                $database,
  String[1]                                $duration,
  Enum['present', 'absent']                $ensure         = 'present',
  Optional[String[1]]                      $shard_duration = undef,
  Integer[1]                               $replicas       = 1,
  Boolean                                  $is_default     = true,
  String[1]                                $admin_username = $influxdb::admin_username,
  Variant[String[1], Sensitive[String[1]]] $admin_password = $influxdb::admin_password,
  Stdlib::Port                             $port           = $influxdb::api_port,
  Boolean                                  $ssl            = $influxdb::_ssl,
) {
  influxdb_retention_policy { "influxdb_rp_${name}_${database}":
    ensure           => $ensure,
    retention_policy => $name,
    database         => $database,
    duration         => $duration,
    shard_duration   => $shard_duration,
    replicas         => $replicas,
    is_default       => $is_default,
    admin_username   => $admin_username,
    admin_password   => $admin_password,
    port             => $port,
    ssl              => $ssl,
    require          => Influxdb_auth['configure_auth'],
  }
}

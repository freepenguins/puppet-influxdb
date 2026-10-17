# @summary Manages an InfluxDB user, its password and its privilege.
#
# A non-admin user gets one privilege on one database. An admin user has all
# privileges on every database. Puppet checks the password by logging in as
# the user, and sets it again if that fails.
#
# @example A read-only user
#   influxdb::user { 'grafana':
#     password  => Sensitive('change-me'),
#     privilege => 'READ',
#     database  => 'telegraf',
#   }
#
# @example A second admin
#   influxdb::user { 'admin2':
#     password => Sensitive('change-me-too'),
#     is_admin => true,
#   }
#
# @param ensure
#   Create or drop the user.
# @param password
#   The user's password. Required unless `ensure` is `absent`.
# @param is_admin
#   Whether the user is an admin.
# @param privilege
#   What a non-admin user may do in `database`.
# @param database
#   The database a non-admin user gets `privilege` on.
# @param admin_username
#   The admin user to log in as. Defaults to `influxdb::admin_username`.
# @param admin_password
#   That user's password. Defaults to `influxdb::admin_password`.
# @param port
#   The HTTP API port. Defaults to `influxdb::api_port`.
# @param ssl
#   Whether the API uses HTTPS. Defaults to `http.https-enabled` in
#   `influxdb::configuration`.
define influxdb::user (
  Enum['present', 'absent']                          $ensure         = 'present',
  Optional[Variant[String[1], Sensitive[String[1]]]] $password       = undef,
  Boolean                                            $is_admin       = false,
  Optional[Enum['READ', 'WRITE', 'ALL']]             $privilege      = undef,
  Optional[String[1]]                                $database       = undef,
  String[1]                                          $admin_username = $influxdb::admin_username,
  Variant[String[1], Sensitive[String[1]]]           $admin_password = $influxdb::admin_password,
  Stdlib::Port                                       $port           = $influxdb::api_port,
  Boolean                                            $ssl            = $influxdb::_ssl,
) {
  if $ensure == 'present' {
    if $password =~ Undef {
      fail("influxdb::user[${name}]: set a password.")
    }
    if !$is_admin and ($privilege =~ Undef or $database =~ Undef) {
      fail("influxdb::user[${name}]: a non-admin user needs a privilege and a database.")
    }
  }

  # An admin has every privilege, on every database.
  $_privilege = $is_admin ? {
    true    => 'ALL',
    default => $privilege,
  }
  $_database = $is_admin ? {
    true    => undef,
    default => $database,
  }

  influxdb_user { "influxdb_user_${name}":
    ensure         => $ensure,
    username       => $name,
    password       => $password,
    is_admin       => $is_admin,
    privilege      => $_privilege,
    database       => $_database,
    admin_username => $admin_username,
    admin_password => $admin_password,
    port           => $port,
    ssl            => $ssl,
    require        => Influxdb_auth['configure_auth'],
  }
}

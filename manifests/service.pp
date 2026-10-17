# @summary Runs the InfluxDB service.
#
# @api private
class influxdb::service {
  assert_private()

  if $influxdb::ensure == 'present' {
    if $influxdb::manage_unit_file {
      systemd::unit_file { 'influxdb.service':
        content => epp("${module_name}/influxdb.service.epp", {
          'config_path' => $influxdb::config_path,
          'owner'       => $influxdb::owner,
          'group'       => $influxdb::group,
        }),
        notify  => Service['influxdb'],
      }
    } else {
      # Remove the override if manage_unit_file was turned off, so the
      # package's unit takes over again.
      systemd::unit_file { 'influxdb.service':
        ensure => absent,
        notify => Service['influxdb'],
      }
    }

    service { 'influxdb':
      ensure => running,
      enable => true,
    }
  } else {
    service { 'influxdb':
      ensure => stopped,
      enable => false,
    }

    systemd::unit_file { 'influxdb.service':
      ensure  => absent,
      require => Service['influxdb'],
    }
  }
}

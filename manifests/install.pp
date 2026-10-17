# @summary Adds InfluxData's repository and installs the InfluxDB package.
#
# @api private
class influxdb::install {
  assert_private()

  case $facts['os']['family'] {
    'Debian': {
      if $influxdb::manage_repo {
        # Strings rather than arrays: puppetlabs-apt accepts arrays only from
        # 10.0.0. With only `name` and `source` in the key hash, apt writes a
        # keyring and signed-by instead of using the deprecated apt-key.
        apt::source { 'influxdb':
          ensure        => $influxdb::ensure,
          comment       => 'InfluxData repository',
          location      => $influxdb::repo_location,
          release       => $influxdb::repo_release,
          repos         => $influxdb::repo_components.join(' '),
          key           => {
            'name'   => $influxdb::repo_key_name,
            'source' => $influxdb::repo_key_source,
          },
          notify_update => true,
        }

        if $influxdb::ensure == 'present' {
          Apt::Source['influxdb'] -> Class['apt::update'] -> Package[$influxdb::package_name]
        }
      }
    }
    'RedHat': {
      if $influxdb::manage_repo {
        yumrepo { 'influxdb':
          ensure   => $influxdb::ensure,
          descr    => 'InfluxData repository',
          baseurl  => $influxdb::repo_location,
          gpgcheck => '1',
          gpgkey   => $influxdb::repo_key_source,
          enabled  => '1',
        }

        if $influxdb::ensure == 'present' {
          Yumrepo['influxdb'] -> Package[$influxdb::package_name]
        }
      }
    }
    default: {
      fail("influxdb: ${facts['os']['family']} is not supported; only Debian and RedHat family systems are.")
    }
  }

  package { $influxdb::package_name:
    ensure => $influxdb::_ensure_package,
  }
}

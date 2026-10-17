# frozen_string_literal: true

require_relative '../influxdb'

require 'puppet/parameter/boolean'

# Attributes every influxdb_* type shares: the admin login, port and HTTPS.
module PuppetX::Influxdb::TypeHelpers
  module_function

  def add_connection_attributes(type)
    type.newparam(:admin_username) do
      desc 'The admin user to log in as.'
    end

    # A property rather than a parameter only so that Puppet can redact a
    # Sensitive value; it never reports a change.
    type.newproperty(:admin_password) do
      desc 'The admin user\'s password.'
      sensitive true

      define_method(:insync?) { |_is| true }
    end

    type.newparam(:port) do
      desc 'The HTTP API port.'
      defaultto 8086
      validate do |value|
        raise ArgumentError, "port must be 1-65535, not #{value.inspect}" unless value.to_s.match?(%r{\A\d+\z}) && value.to_i.between?(1, 65_535)
      end
      munge { |value| Integer(value) }
    end

    type.newparam(:ssl, boolean: true, parent: Puppet::Parameter::Boolean) do
      desc 'Whether the HTTP API uses HTTPS (`http.https-enabled`).'
      defaultto :false
    end
  end
end

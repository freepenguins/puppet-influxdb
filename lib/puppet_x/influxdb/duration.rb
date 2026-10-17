# frozen_string_literal: true

require_relative '../influxdb'

# Compares InfluxQL durations. InfluxDB shows a policy's duration as Go
# does (`8736h0m0s`), so `52w`, `364d` and `8736h0m0s` are the same.
module PuppetX::Influxdb::Duration
  UNITS = {
    'ns' => 1,
    'u' => 1_000,
    'µ' => 1_000,
    'ms' => 1_000_000,
    's' => 1_000_000_000,
    'm' => 60 * 1_000_000_000,
    'h' => 3600 * 1_000_000_000,
    'd' => 86_400 * 1_000_000_000,
    'w' => 604_800 * 1_000_000_000,
  }.freeze
  PART = %r{(\d+)(ns|ms|u|µ|s|m|h|d|w)}
  FORMAT = %r{\A(?:#{PART})+\z}

  module_function

  # True for a duration literal InfluxQL accepts, or INF.
  def valid?(value)
    value = value.to_s.strip
    value.casecmp('INF').zero? || value.match?(FORMAT)
  end

  # The duration in nanoseconds. INF and 0 are both 0, which is how
  # InfluxDB shows "keep forever".
  def to_ns(value)
    value = value.to_s.strip
    return 0 if value.casecmp('INF').zero?
    raise ArgumentError, "invalid InfluxQL duration: #{value.inspect}" unless value.match?(FORMAT)

    value.scan(PART).sum { |number, unit| number.to_i * UNITS.fetch(unit) }
  end

  def same?(left, right)
    to_ns(left) == to_ns(right)
  rescue ArgumentError
    false
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/influxdb/duration'

describe PuppetX::Influxdb::Duration do
  it 'treats the ways InfluxDB and people write a duration as equal' do
    expect(described_class.same?('52w', '8736h0m0s')).to be true
    expect(described_class.same?('30d', '720h0m0s')).to be true
    expect(described_class.same?('1h30m', '90m')).to be true
    expect(described_class.same?('INF', '0s')).to be true
    expect(described_class.same?('inf', '0s')).to be true
  end

  it 'tells different durations apart' do
    expect(described_class.same?('52w', '8760h0m0s')).to be false
    expect(described_class.same?('1d', 'garbage')).to be false
  end

  it 'accepts only InfluxQL duration literals' do
    expect(described_class.valid?('52w')).to be true
    expect(described_class.valid?('1h30m')).to be true
    expect(described_class.valid?('500ms')).to be true
    expect(described_class.valid?('INF')).to be true
    expect(described_class.valid?('1 year')).to be false
    expect(described_class.valid?('7d; DROP DATABASE x')).to be false
    expect(described_class.valid?('')).to be false
  end
end

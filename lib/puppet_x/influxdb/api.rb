# frozen_string_literal: true

require_relative '../influxdb'

require 'json'
require 'net/http'
require 'openssl'

# Runs InfluxQL through InfluxDB 1.x's HTTP API on localhost.
#
# Statements go in a POST body and credentials in an Authorization
# header, so neither shows up in process lists or Puppet's debug output.
module PuppetX::Influxdb::Api
  # A statement InfluxDB rejected, or a server that couldn't be reached.
  class Error < Puppet::Error; end

  # Characters InfluxQL treats as special inside quotes.
  ESCAPES = { '\\' => '\\\\', '"' => '\\"', "'" => "\\'" }.freeze

  module_function

  # Runs one or more statements and returns the parsed `results` array.
  # Raises Api::Error if InfluxDB reports an error.
  def execute(statement, username: nil, password: nil, port: 8086, ssl: false)
    response = post(statement, username: username, password: password, port: port, ssl: ssl)
    body = parse(response)
    error = body['error'] || Array(body['results']).map { |r| r['error'] }.compact.first
    raise Error, "InfluxDB: #{error}" if error
    raise Error, "InfluxDB answered HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    body['results'] || []
  end

  # Like execute, but returns false instead of raising.
  def succeeds?(statement, **opts)
    execute(statement, **opts)
    true
  rescue Error
    false
  end

  # The rows of a single statement's first series, as hashes keyed by
  # column; [] when there are none.
  def rows(statement, **opts)
    series = Array(execute(statement, **opts).first&.fetch('series', nil)).first
    return [] if series.nil?

    columns = series['columns']
    Array(series['values']).map { |values| columns.zip(values).to_h }
  end

  # Quotes an identifier, such as a database or user name.
  def ident(name)
    %("#{name.to_s.gsub(%r{[\\"]}, ESCAPES)}")
  end

  # Quotes a string literal, such as a password.
  def string(value)
    %('#{value.to_s.gsub(%r{[\\']}, ESCAPES)}')
  end

  def post(statement, username:, password:, port:, ssl:)
    http = Net::HTTP.new('localhost', port)
    http.open_timeout = 10
    http.read_timeout = 60
    if ssl
      # It's our own server on localhost, often with a self-signed
      # certificate.
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Post.new('/query')
    request.basic_auth(username.to_s, password.to_s) unless username.to_s.empty?
    request.set_form_data('q' => statement)
    http.request(request)
  rescue SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
    raise Error, "can't reach InfluxDB on localhost:#{port}: #{e.message}"
  end

  def parse(response)
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError
    raise Error, "InfluxDB answered HTTP #{response.code} with: #{response.body.to_s.strip[0, 200]}"
  end
end

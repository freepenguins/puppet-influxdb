# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/influxdb/api'

describe PuppetX::Influxdb::Api do
  def response(code, body)
    klass = Net::HTTPResponse::CODE_TO_OBJ[code.to_s]
    klass.new('1.1', code.to_s, '').tap { |r| allow(r).to receive(:body).and_return(body) }
  end

  let(:http) { instance_double(Net::HTTP, 'open_timeout=': nil, 'read_timeout=': nil) }
  let(:sent) { [] }

  before(:each) do
    allow(Net::HTTP).to receive(:new).with('localhost', 8086).and_return(http)
  end

  def answer(code, body)
    allow(http).to receive(:request) do |request|
      sent << request
      response(code, body)
    end
  end

  it 'posts the statement with basic auth and returns the results' do
    answer(200, '{"results":[{"statement_id":0}]}')
    expect(described_class.execute('SHOW USERS', username: 'admin', password: 'p@ss')).to eq([{ 'statement_id' => 0 }])
    expect(sent.first.path).to eq('/query')
    expect(sent.first.body).to eq('q=SHOW+USERS')
    expect(sent.first['authorization']).to eq("Basic #{['admin:p@ss'].pack('m0')}")
  end

  it 'sends no credentials when there is no username' do
    answer(200, '{"results":[{}]}')
    described_class.execute('SHOW USERS')
    expect(sent.first['authorization']).to be_nil
  end

  it 'raises on a server error' do
    answer(401, '{"error":"authorization failed"}')
    expect { described_class.execute('SHOW USERS') }.to raise_error(described_class::Error, %r{authorization failed})
  end

  it 'raises on a statement error' do
    answer(200, '{"results":[{"statement_id":0,"error":"user not found"}]}')
    expect { described_class.execute('SHOW GRANTS FOR "x"') }.to raise_error(described_class::Error, %r{user not found})
  end

  it 'raises on a response that isn\'t JSON' do
    answer(502, '<html>Bad Gateway</html>')
    expect { described_class.execute('SHOW USERS') }.to raise_error(described_class::Error, %r{HTTP 502})
  end

  it 'raises when nothing listens on the port' do
    allow(http).to receive(:request).and_raise(Errno::ECONNREFUSED)
    expect { described_class.execute('SHOW USERS') }.to raise_error(described_class::Error, %r{can't reach InfluxDB})
  end

  it 'reports success or failure without raising' do
    answer(401, '{"error":"authorization failed"}')
    expect(described_class.succeeds?('SHOW USERS')).to be false
  end

  it 'turns a series into rows' do
    answer(200, '{"results":[{"series":[{"columns":["user","admin"],"values":[["admin",true],["grafana",false]]}]}]}')
    expect(described_class.rows('SHOW USERS')).to eq([{ 'user' => 'admin', 'admin' => true }, { 'user' => 'grafana', 'admin' => false }])
  end

  it 'returns no rows for a series without values or no series at all' do
    answer(200, '{"results":[{"series":[{"name":"databases","columns":["name"]}]}]}')
    expect(described_class.rows('SHOW DATABASES')).to eq([])
    answer(200, '{"results":[{"statement_id":0}]}')
    expect(described_class.rows('SHOW USERS')).to eq([])
  end

  it 'uses HTTPS without verifying our own certificate' do
    allow(Net::HTTP).to receive(:new).with('localhost', 8443).and_return(http)
    expect(http).to receive(:use_ssl=).with(true)
    expect(http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    answer(200, '{"results":[{}]}')
    described_class.execute('SHOW USERS', port: 8443, ssl: true)
  end

  it 'quotes identifiers and strings' do
    expect(described_class.ident('my "db"')).to eq('"my \"db\""')
    expect(described_class.ident('back\\slash')).to eq('"back\\\\slash"')
    expect(described_class.string("it's")).to eq("'it\\'s'")
    expect(described_class.string('a"b')).to eq(%('a"b'))
  end
end

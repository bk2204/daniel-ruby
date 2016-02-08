#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Daniel::JWT do
  def example
    ['eyJhbGciOiJIUzI1NiIsImtpZCI6IjE6NDA5NjowMDAwMDAiLCJ0eXAiOiJKV1QifQ.',
     'eyJhZG1pbiI6dHJ1ZSwibmFtZSI6IkpvaG4gRG9lIiwic3ViIjoiMTIzNDU2Nzg5MCJ9.',
     '_FRrQNpNFRrOcjy-K8Vc7wIY-p0PyjwyWO9mAvQIlsY'].join
  end

  def key_id
    '1:4096:000000'
  end

  it 'has a valid header' do
    expect { JSON.parse(Daniel::JWT::HEADER) }.not_to raise_error
  end

  it 'has a header that contains the expected items' do
    expect(JSON.parse(Daniel::Util.from_url64(example.split('.')[0]))).to eq(
      'alg' => 'HS256',
      'kid' => key_id,
      'typ' => 'JWT'
    )
  end

  it 'validates data correctly' do
    j = nil
    expect { j = Daniel::JWT.parse(example, 'secret') }.not_to raise_error
    expect(j.valid?).to eq true
    expect { j.validate }.not_to raise_error

    s = example.sub(/...$/, 'abc')
    expect do
      j = Daniel::JWT.parse(s, 'secret')
    end.to raise_error(Daniel::JWTValidationError)
    j = Daniel::JWT.parse(s)
    j.key = 'secret'
    expect(j.valid?).to eq false
    expect { j.validate }.to raise_error(Daniel::JWTValidationError)
  end

  it 'round-trips properly' do
    j = Daniel::JWT.parse(example, 'secret')
    expect(j.to_s).to eq example
  end

  it 'round-trips payload properly' do
    data = {
      :admin => true,
      :name => 'John Doe',
      :sub => '1234567890'
    }
    j = Daniel::JWT.new(data, :key => 'secret', :key_id => key_id)
    expect(j.payload).to eq data
    expect(j.to_s).to eq example
  end

  it 'parses JSON properly' do
    j = Daniel::JWT.parse(example, 'secret')
    data = {
      :admin => true,
      :name => 'John Doe',
      :sub => '1234567890'
    }
    expect(j.payload).to eq data
  end

  it 'canonicalizes JSON properly' do
    data = {
      :d => 4,
      :b => 2,
      :f => 10,
      :c => 3,
      :g => 7,
      :a => 26,
      :h => 8,
      :e => 9
    }
    canon = '{"a":26,"b":2,"c":3,"d":4,"e":9,"f":10,"g":7,"h":8}'
    expect(Daniel::JWT.canonical_json(data)).to eq canon
  end
end

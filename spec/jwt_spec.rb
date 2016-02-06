#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')


describe Daniel::JWT do
  def example
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' \
    'eyJhZG1pbiI6dHJ1ZSwibmFtZSI6IkpvaG4gRG9lIiwic3ViIjoiMTIzNDU2Nzg5MCJ9.' \
    'eNK_fimsCW3Q-meOXyc_dnZHubl2D4eZkIcn6llniCk'
  end

  it 'has a valid header' do
    expect { JSON.parse(Daniel::JWT::HEADER) }.not_to raise_error
  end

  it 'validates data correctly' do
    j = nil
    expect { j = Daniel::JWT.parse(example, 'secret') }.not_to raise_error
    expect(j.valid?).to eq true
    expect { j.validate }.not_to raise_error

    s = example.sub(/...$/, 'abc')
    expect { j = Daniel::JWT.parse(s, 'secret') }.to \
      raise_error(Daniel::JWTValidationError)
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
      :name => "John Doe",
      :sub => "1234567890"
    }
    j = Daniel::JWT.new(data, nil, 'secret')
    expect(j.payload).to eq data
    expect(j.to_s).to eq example
  end

  it 'parses JSON properly' do
    j = Daniel::JWT.parse(example, 'secret')
    data = {
      :admin => true,
      :name => "John Doe",
      :sub => "1234567890"
    }
    expect(j.payload).to eq data
  end
end

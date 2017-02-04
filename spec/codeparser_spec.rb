#!/usr/bin/ruby
# encoding: UTF-8

require 'spec_helper'

describe Daniel::CodeParser do
  it 'should return the code for items which are not specially formatted' do
    code = 'example.tld'
    parsed = Daniel::CodeParser.parse(code)
    expect(parsed).to eq(:code => code)
  end

  it 'should handle pass: codes correctly' do
    code = 'pass:doe%40nic.tld@example.com'
    parsed = Daniel::CodeParser.parse(code)
    expect(parsed).to eq(:code => code, :username => 'doe@nic.tld',
                         :domain => 'example.com', :type => :pass)
  end

  it 'should handle pin: codes correctly' do
    code = 'pin:doe%40nic.tld@example.com'
    parsed = Daniel::CodeParser.parse(code)
    expect(parsed).to eq(:code => code, :username => 'doe@nic.tld',
                         :domain => 'example.com', :type => :pin)
  end

  it 'should handle pin: codes without usernames correctly' do
    code = 'pin:example.com'
    parsed = Daniel::CodeParser.parse(code)
    expect(parsed).to eq(:code => code, :domain => 'example.com', :type => :pin)
  end
end

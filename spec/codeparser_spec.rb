#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')

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
                         :domain => 'example.com')
  end
end
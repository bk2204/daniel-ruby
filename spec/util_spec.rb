#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Daniel::Util do
  it 'converts hex to binary as expected' do
    expected = "\x00A7\x80"
    if Daniel::Version.smart_implementation?
      expected = expected.force_encoding('BINARY')
    end
    expect(Daniel::Util.from_hex('00413780')).to eq expected
  end
  it 'converts hex to binary as expected' do
    expect(Daniel::Util.to_hex("\x00A7\x80")).to eq '00413780'
  end
end

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

  it 'converts data to base64 as expected' do
    expect(Daniel::Util.to_base64('abcdefg')).to eq 'YWJjZGVmZw=='
    expect(Daniel::Util.to_base64('hij')).to eq 'aGlq'
    expect(Daniel::Util.to_base64("klmn\n")).to eq 'a2xtbgo='
  end

  it 'converts data from base64 as expected' do
    expect(Daniel::Util.from_base64('YWJjZGVmZw==')).to eq 'abcdefg'
    expect(Daniel::Util.from_base64('aGlq')).to eq 'hij'
    expect(Daniel::Util.from_base64('a2xtbgo=')).to eq "klmn\n"
  end

  it 'converts data to url64 as expected' do
    expect(Daniel::Util.to_url64('abcdefg')).to eq 'YWJjZGVmZw'
    expect(Daniel::Util.to_url64('hij')).to eq 'aGlq'
    expect(Daniel::Util.to_url64("klmn\n")).to eq 'a2xtbgo'
  end

  it 'converts data from url64 as expected' do
    expect(Daniel::Util.from_url64('YWJjZGVmZw')).to eq 'abcdefg'
    expect(Daniel::Util.from_url64('aGlq')).to eq 'hij'
    expect(Daniel::Util.from_url64('a2xtbgo')).to eq "klmn\n"
  end
end

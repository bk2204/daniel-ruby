#!/usr/bin/ruby
# encoding: UTF-8

require_relative 'spec_helper'

describe Daniel::Util do
  it 'converts hex to binary as expected' do
    expected = "\x00A7\x80"
    expected = expected.force_encoding('BINARY') if ::RUBY_VERSION.to_f > 1.8
    expect(Daniel::Util.from_hex('00413780')).to eq expected
  end
  it 'converts hex to binary as expected' do
    expect(Daniel::Util.to_hex("\x00A7\x80")).to eq '00413780'
  end
end

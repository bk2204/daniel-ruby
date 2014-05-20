#!/usr/bin/ruby
# encoding: UTF-8

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

describe Daniel do
  it "converts hex to binary as expected" do
    expected = "\x00A7\x80".force_encoding("BINARY")
    expect(Daniel.from_hex("00413780")).to eq expected
  end
  it "converts hex to binary as expected" do
    expect(Daniel.to_hex("\x00A7\x80")).to eq "00413780"
  end
end

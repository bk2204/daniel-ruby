#!/usr/bin/ruby
# encoding: UTF-8

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

describe Daniel::Flags do
  it "returns an identical mask if it's a number" do
    (0x00..0x7f).each do |x|
      expect(Daniel::Flags.mask_from_characters(x)).to eq x
    end
  end

  it "returns the correct mask if it's an octal string" do
    (0x00..0x7f).each do |x|
      expect(Daniel::Flags.mask_from_characters(format("%#o", x))).to eq x
    end
  end

  it "returns the correct mask if it's a lowercase hex string" do
    (0x00..0x7f).each do |x|
      expect(Daniel::Flags.mask_from_characters(format("%#x", x))).to eq x
    end
  end

  it "returns the correct mask if it's an uppercase hex string" do
    (0x00..0x7f).each do |x|
      expect(Daniel::Flags.mask_from_characters(format("%#X", x))).to eq x
    end
  end

  [
    ['-', 0x17],
    ['as', 0x0d],
    ['A ', 0x0d],
    ['!:', 0x13],
    ['0as!+', 0x00],
    ['A -', 0x05],
  ].each do |(mask, value)|
    it "returns the correct mask for '#{mask}'" do
      expect(Daniel::Flags.mask_from_characters(mask)).to eq value
    end
  end
end

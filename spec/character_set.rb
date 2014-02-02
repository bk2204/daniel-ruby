#!/usr/bin/ruby
# encoding: UTF-8

$:.unshift File.join(File.dirname(__FILE__), '..')

load 'daniel'

describe Daniel::CharacterSet do
  it "contains all expected bytes for 0" do
    set = Daniel::CharacterSet.new 0
    (0x20..0x7e).each do |x|
      set.should include x
    end
  end
  it "contains no other bytes for 0" do
    set = Daniel::CharacterSet.new 0
    (0x0..0x1f).each do |x|
      set.should_not include x
    end
    (0x7f..0xff).each do |x|
      set.should_not include x
    end
  end
  it "contains no bytes for SYMBOL_MASK" do
    set = Daniel::CharacterSet.new Daniel::CharacterSet::SYMBOL_MASK
    (0x20..0x7e).each do |x|
      set.should_not include x
    end
  end
end

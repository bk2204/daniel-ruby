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
  context "in from_characters" do
    it "returns the same thing as new for a Fixnum" do
      (0..Daniel::CharacterSet::SYMBOL_MASK).each do |value|
        set = Daniel::CharacterSet.new value
        cs = Daniel::CharacterSet.from_characters value
        (0x0..0xff).each do |x|
          set.include?(x).should eq cs.include?(x)
        end
      end
    end
    it "converts a string to an integer if it is decimal" do
      (0..Daniel::CharacterSet::SYMBOL_MASK).each do |value|
        set = Daniel::CharacterSet.new value
        cs = Daniel::CharacterSet.from_characters value.to_s
        (0x0..0xff).each do |x|
          set.include?(x).should eq cs.include?(x)
        end
      end
    end
    it "converts a string to an integer if it is octal" do
      (0..Daniel::CharacterSet::SYMBOL_MASK).each do |value|
        set = Daniel::CharacterSet.new value
        cs = Daniel::CharacterSet.from_characters "0" + value.to_s(8)
        (0x0..0xff).each do |x|
          set.include?(x).should eq cs.include?(x)
        end
      end
    end
    it "converts a string to an integer if it is hexadecimal" do
      (0..Daniel::CharacterSet::SYMBOL_MASK).each do |value|
        set = Daniel::CharacterSet.new value
        cs = Daniel::CharacterSet.from_characters "0x" + value.to_s(16)
        (0x0..0xff).each do |x|
          set.include?(x).should eq cs.include?(x)
        end
      end
    end
    it "contains only letters and numbers for 'a0'" do
      csc = Daniel::CharacterSet
      mask = csc::NO_SPACES | csc::NO_SYMBOLS_TOP | csc::NO_SYMBOLS_OTHER
      set = Daniel::CharacterSet.new mask
      cs = Daniel::CharacterSet.from_characters "a0"
      (0x0..0xff).each do |x|
        set.include?(x).should eq cs.include?(x)
      end
    end
  end
end

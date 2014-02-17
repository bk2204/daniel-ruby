#!/usr/bin/ruby
# encoding: UTF-8

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

describe Daniel::PasswordGenerator do
  [
    ["foo", "8244c50a1000bar", "8244c5", 10, 16, 0, "bar"],
    ["foo", "8244c50a1000baz", "8244c5", 10, 16, 0, "baz"],
    ["bar", "ca67960a1000la-france", "ca6796", 10, 16, 0, "la-france"],
    ["foo", "8244c5253264la-france", "8244c5", 37, 50, 100, "la-france"],
    ["foo", "8244c525810001la-france", "8244c5", 37, 128, 1, "la-france"],
    ["foo", "8244c5258100ab22la-france", "8244c5", 37, 128, 5538, "la-france"],
  ].each do |items|
    password, reminder, csum, flags, length, version, code = items
    it "gives the expected values for #{reminder}" do
      pieces = Daniel::PasswordGenerator.parse_reminder(reminder)
      pieces[:checksum].should == csum
      pieces[:code].should == code
      pieces[:params].flags.should == flags
      pieces[:params].length.should == length
      pieces[:params].version.should == version
    end

    it "generates the expected values of #{reminder}" do
      gen = Daniel::PasswordGenerator.new(password)
      params = Daniel::Parameters.new(flags, length, version)
      gen.reminder(code, params).should == reminder
    end
  end
end

#!/usr/bin/ruby
# encoding: UTF-8

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

describe Daniel::PasswordGenerator do
  [
    ["foobar", "abcdefg", "5cce7fa060352fd4", "password", "72eb36200800"],
    ["foobar", "abcdefg", "41d62da57228248f609ad35fb44758d2d948c7d0726796",
     "my!very?secret*passw0rd", "72eb36201700"],
  ].each do |items|
    master, code, mask, result, remroot = items
    rawmask = [mask].pack("H*")
    reminder = [remroot, mask, code].join

    it "gives the expected password for #{master}, #{mask}, #{code}" do
      gen = Daniel::PasswordGenerator.new master
      params = Daniel::Parameters.new(Daniel::Flags::REPLICATE_EXISTING,
                                      result.length)
      expect(gen.generate(code, params, rawmask)).to eq(result)
    end
    it "gives the expected reminder for #{master}, #{mask}, #{code}" do
      gen = Daniel::PasswordGenerator.new master
      params = Daniel::Parameters.new(Daniel::Flags::REPLICATE_EXISTING,
                                      result.length)
      expect(gen.reminder(code, params, rawmask)).to eq(reminder)
    end
    it "gives the expected password for #{master}, #{mask}, #{code} reminder" do
      gen = Daniel::PasswordGenerator.new master
      expect(gen.generate_from_reminder(reminder)).to eq(result)
    end
  end
end

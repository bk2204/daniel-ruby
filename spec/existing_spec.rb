#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Daniel::PasswordGenerator do
  [
    %w(foobar abcdefg 5cce7fa060352fd4 password 72eb36200800),
    %w(foobar abcdefg 41d62da57228248f609ad35fb44758d2d948c7d0726796
       my!very?secret*passw0rd 72eb36201700),
    %w(foobar example.tld 95fb1346e2bec1670fb782fd51c8ac09 verylongpassword
       72eb36201000)
  ].each do |items|
    master, code, mask, result, remroot = items
    rawmask = Daniel::Util.from_hex(mask)
    reminder = [remroot, mask, code].join
    testname = "#{master}, #{mask}, #{code}"

    it "gives the expected password for #{testname}" do
      gen = Daniel::PasswordGenerator.new master
      params = Daniel::Parameters.new(Daniel::Flags::REPLICATE_EXISTING,
                                      result.length)
      expect(gen.generate(code, params, rawmask)).to eq(result)
    end

    it "gives the expected mask for password for #{testname}" do
      gen = Daniel::PasswordGenerator.new master
      params = Daniel::Parameters.new(Daniel::Flags::REPLICATE_EXISTING,
                                      result.length)
      expect(gen.generate_mask(code, params, result)).to eq(rawmask)
    end

    it "gives the expected reminder for #{testname}" do
      gen = Daniel::PasswordGenerator.new master
      params = Daniel::Parameters.new(Daniel::Flags::REPLICATE_EXISTING,
                                      result.length)
      expect(gen.reminder(code, params, rawmask)).to eq(reminder)
    end

    it "gives the expected password for #{testname} reminder" do
      gen = Daniel::PasswordGenerator.new master
      expect(gen.generate_from_reminder(reminder)).to eq(result)
    end

    it "gives an all-NUL mask for password ^ mask for #{testname}" do
      gen = Daniel::PasswordGenerator.new master
      params = Daniel::Parameters.new(Daniel::Flags::REPLICATE_EXISTING,
                                      result.length)
      xorout = result.bytes.zip(rawmask.bytes).map do |a|
        (a[0] ^ a[1]).chr
      end.join
      nuls = "\x00" * result.length
      expect(gen.generate_mask(code, params, xorout)).to eq(nuls)
      expect(gen.generate_mask(code, params, nuls)).to eq(xorout)
    end

    it "gives an all-NUL password for password ^ mask for #{testname}" do
      gen = Daniel::PasswordGenerator.new master
      params = Daniel::Parameters.new(Daniel::Flags::REPLICATE_EXISTING,
                                      result.length)
      xorout = result.bytes.zip(rawmask.bytes).map do |a|
        (a[0] ^ a[1]).chr
      end.join
      nuls = "\x00" * result.length
      expect(gen.generate(code, params, xorout)).to eq(nuls)
      expect(gen.generate(code, params, nuls)).to eq(xorout)
    end
  end
end

#!/usr/bin/ruby
# encoding: UTF-8

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

describe Daniel::PasswordGenerator do
  [
    ['foo', '8244c50a1000bar', '8244c5', 10, 16, 0, 'bar'],
    ['foo', '8244c50a1000baz', '8244c5', 10, 16, 0, 'baz'],
    ['bar', 'ca67960a1000la-france', 'ca6796', 10, 16, 0, 'la-france'],
    ['foo', '8244c5203264la-france', '8244c5', 32, 50, 100, 'la-france'],
    ['foo', '8244c520810001la-france', '8244c5', 32, 128, 1, 'la-france'],
    ['foo', '8244c5208100ab22la-france', '8244c5', 32, 128, 5538, 'la-france']
  ].each do |items|
    password, reminder, csum, flags, length, version, code = items
    it "gives the expected values for #{reminder}" do
      pieces = Daniel::PasswordGenerator.parse_reminder(reminder)
      expect(pieces[:checksum]).to eq(csum)
      expect(pieces[:code]).to eq(code)
      expect(pieces[:params].flags).to eq(flags)
      expect(pieces[:params].length).to eq(length)
      expect(pieces[:params].version).to eq(version)
    end

    it "generates the expected values of #{reminder}" do
      gen = Daniel::PasswordGenerator.new(password)
      params = Daniel::Parameters.new(flags, length, version)
      expect(gen.reminder(code, params)).to eq(reminder)
    end
  end
end

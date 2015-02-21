#!/usr/bin/ruby
# encoding: UTF-8

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

describe Daniel::Reminder do
  [
    ['foo', '8244c50a1000bar', '8244c5', 10, 16, 0, 'bar'],
    ['foo', '8244c50a1000baz', '8244c5', 10, 16, 0, 'baz'],
    ['bar', 'ca67960a1000la-france', 'ca6796', 10, 16, 0, 'la-france'],
    ['foo', '8244c50c3264la-france', '8244c5', 12, 50, 100, 'la-france'],
    ['foo', '8244c50c810001la-france', '8244c5', 12, 128, 1, 'la-france'],
    ['foo', '8244c50c8100ab22la-france', '8244c5', 12, 128, 5538, 'la-france'],
    ['foo', '8244c5200301000000la-france', '8244c5', 32, 3, 1, 'la-france',
     "\x00\x00\x00"]
  ].each do |items|
    password, reminder, csum, flags, length, version, code, mask = items
    it "gives the expected values for #{reminder}" do
      pieces = Daniel::Reminder.parse(reminder)
      expect(pieces[:checksum]).to eq(csum)
      expect(pieces[:code]).to eq(code)
      expect(pieces[:params].flags).to eq(flags)
      expect(pieces[:params].length).to eq(length)
      expect(pieces[:params].version).to eq(version)
    end

    it "generates the expected values of #{reminder}" do
      gen = Daniel::PasswordGenerator.new(password)
      params = Daniel::Parameters.new(flags, length, version)
      expect(gen.reminder(code, params, mask)).to eq(reminder)
    end
  end

  it 'raises an exception for reminder missing mask' do
    expect { Daniel::Reminder.parse('8244c520810001la-france') } \
      .to raise_error(Daniel::Exception, /mask missing/)
  end
end

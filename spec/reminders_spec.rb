#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Daniel::Reminder do
  # A basic 16-character passphrase.
  def example
    '72eb364001812f' \
      'eyJhbGciOiJIUzI1NiIsImtpZCI6IjE6NDA5Njo3MmViMzYiLCJ0eXAiOiJKV1QifQ.' \
      'eyJjb2RlIjoiZXhhbXBsZS50bGQiLCJmbGciOjY0LCJsZW4iOjE2LCJ2ZXIiOjB9.' \
      'F58yIKd7IDmYxGRpkgr6UWOn3ZTUTgjowK2RUu_VLG8' \
      'example.tld'
  end

  # A 12-character passphrase with salt and mask.
  def example2
    'ca679660018162' \
      'eyJhbGciOiJIUzI1NiIsImtpZCI6IjE6ODE5MjpjYTY3OTY6QUFBQUFBQUFBQUFBIiw' \
      'idHlwIjoiSldUIn0.' \
      'eyJjb2RlIjoiZXhhbXBsZS5jb20iLCJmbGciOjk2LCJsZW4iOjEyLCJtc2siOiJfX19' \
      'fX19fX19fX19fX19fIiwidmVyIjoyfQ.' \
      '7YhYmorl6qcKy2LeKfJDKrSi-d5r6c8VL8adJxNPfbY' \
      'example.com'
  end

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

    it 'produces the correct values when parsed by generator' do
      gen = Daniel::PasswordGenerator.new(password)
      pieces = gen.parse_reminder(reminder)
      expect(pieces[:checksum]).to eq(csum)
      expect(pieces[:code]).to eq(code)
      expect(pieces[:params].flags).to eq(flags)
      expect(pieces[:params].length).to eq(length)
      expect(pieces[:params].version).to eq(version)
    end
  end

  it 'parses basic v1 reminders' do
    s = example
    m = /\.([A-Za-z0-9_-]+)example\.tld$/.match(s)
    mac = Daniel::Util.from_url64(m[1])
    k = Daniel::Util.from_url64('w6vSGl3w_iEO8qhoCRO2vRxRqMY-3AK7-QasPXSrEIY')
    r = Daniel::Reminder.parse(s, :mac_key => k)
    expect(r.checksum).to eq '72eb36'
    expect(r.params.format_version).to eq 1
    expect(r.params.flags).to eq 0x40
    expect(r.params.version).to eq 0
    expect(r.params.length).to eq 16
    expect(r.params.iterations).to eq 4096
    expect(r.params.salt).to be nil
    expect(r.code).to eq 'example.tld'
    expect(r.mac).to eq mac
    expect(r.anonymous?).to be false
    p = Daniel::Reminder.parse_header(s)
    expect(p.format_version).to eq 1
    expect(p.flags).to eq 0x40
    expect(p.iterations).to eq 4096
    expect(p.salt).to be nil
  end

  it 'parses v1 reminders with all features' do
    s = example2
    m = /\.([A-Za-z0-9_-]+)example\.com$/.match(s)
    mac = Daniel::Util.from_url64(m[1])
    k = Daniel::Util.from_url64('6_DXNpxRaNa7K-7dC_Xb7yqacik2NiVlAjB6SSYANdw')
    r = Daniel::Reminder.parse(s, :mac_key => k)
    expect(r.checksum).to eq 'ca6796'
    expect(r.params.format_version).to eq 1
    expect(r.params.flags).to eq 0x60
    expect(r.params.version).to eq 2
    expect(r.params.length).to eq 12
    expect(r.params.iterations).to eq 8192
    expect(r.params.salt).to eq "\x00" * 9
    expect(r.mask).to eq Daniel::Util.to_binary("\xff") * 12
    expect(r.code).to eq 'example.com'
    expect(r.mac).to eq mac
    expect(r.anonymous?).to be false
    p = Daniel::Reminder.parse_header(s)
    expect(p.format_version).to eq 1
    expect(p.flags).to eq 0x60
    expect(p.iterations).to eq 8192
    expect(p.salt).to eq "\x00" * 9
  end

  it 'can create v1 reminders' do
    params = Daniel::Parameters.new(0x40, 16, 0, :iterations => 4096,
                                                 :format_version => 1)
    s = example
    k = Daniel::Util.from_url64('w6vSGl3w_iEO8qhoCRO2vRxRqMY-3AK7-QasPXSrEIY')
    r = Daniel::Reminder.new(params, '72eb36', 'example.tld', nil,
                             :mac_key => k)
    expect(r.to_s).to eq s
  end

  it 'can create v1 reminders with all features' do
    params = Daniel::Parameters.new(0x60, 12, 2, :iterations => 8192,
                                                 :salt => "\x00" * 9,
                                                 :format_version => 1)
    s = example2
    k = Daniel::Util.from_url64('6_DXNpxRaNa7K-7dC_Xb7yqacik2NiVlAjB6SSYANdw')
    r = Daniel::Reminder.new(params, 'ca6796', 'example.com',
                             Daniel::Util.to_binary("\xff") * 12,
                             :mac_key => k)
    expect(r.to_s).to eq s
  end

  it 'refuses to serialize v1 reminders with no key' do
    params = Daniel::Parameters.new(0x60, 12, 2, :iterations => 8192,
                                                 :salt => "\x00" * 9,
                                                 :format_version => 1)
    r = Daniel::Reminder.new(params, '987654', 'example.com',
                             Daniel::Util.to_binary("\xff") * 12)
    expect { r.to_s }.to raise_error(Daniel::MissingDataError)
  end

  it 'raises an exception for reminder missing mask' do
    expect { Daniel::Reminder.parse('8244c520810001la-france') } \
      .to raise_error(Daniel::InvalidReminderError, /mask missing/)
  end
end

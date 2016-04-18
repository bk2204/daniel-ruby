#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Daniel::PasswordGenerator do
  def reminder
    # Broken out into the constituent components.
    '72eb36' \
      '8140' \
      '01' \
      '814d' \
      'eyJhbGciOiJIUzI1NiIsImtpZCI6IjE6NDA5Njo3MmViMzY6YzI5a2FYVnRJR05vYkc5e' \
      'WFXUmwiLCJ0eXAiOiJKV1QifQ.' \
      'eyJjb2RlIjoiZXhhbXBsZS50bGQiLCJmbGciOjE5MiwibGVuIjoyMCwidmVyIjozfQ.' \
      'Hsu6WskpGVZNF3PDKpFW3oQo4LULHHEz1glbPZn8EK4' \
      'example.tld'
  end

  def zero_reminder
    # Broken out into the constituent components.
    '000000' \
      '8140' \
      '01' \
      '814d' \
      'eyJhbGciOiJIUzI1NiIsImtpZCI6IjE6NDA5NjowMDAwMDA6YzI5a2FYVnRJR05vYkc5e' \
      'WFXUmwiLCJ0eXAiOiJKV1QifQ.' \
      'eyJjb2RlIjoiZXhhbXBsZS50bGQiLCJmbGciOjE5MiwibGVuIjoyMCwidmVyIjozfQ.' \
      '7d5C_sBJh-Mg3gPGm0LAkR1TtJADKT6hSyXdUXHvD5o' \
      'example.tld'
  end

  def byte_sequence
    Daniel::Util.from_hex('957a076a3eda9845b2d611946d4e2334edc1c044')
  end

  it 'should produce the expected master secret' do
    gen = Daniel::PasswordGenerator.new('foobar', 1)
    ms = gen.instance_variable_get(:@master_secret)
    expect(Daniel::Util.to_hex(ms)).to eq \
      'ae0d92311b2284234a7c2bd4799bfd1aac71fc222b85db64e9d9a144d95eda94'
  end

  it 'should produce the same master secret as for v0' do
    g0 = Daniel::PasswordGenerator.new('foobar', 0)
    g1 = Daniel::PasswordGenerator.new('foobar', 1)
    ms0 = g0.instance_variable_get(:@master_secret)
    ms1 = g1.instance_variable_get(:@master_secret)
    expect(ms0).to eq ms1
  end

  # Write the code out as a full implementation to make sure that we didn't mess
  # something up somewhere.
  it 'should generate the expected byte sequence' do
    gen = Daniel::PasswordGenerator.new('foobar', 1)
    salt = 'sodium chloride'
    len = 20
    params = Daniel::Parameters.new(0xc0, len, 3, :iterations => 4096,
                                                  :format_version => 1,
                                                  :salt => salt)
    seq = gen.generate('example.tld', params)

    mshex = 'ae0d92311b2284234a7c2bd4799bfd1aac71fc222b85db64e9d9a144d95eda94'
    ms = Daniel::Util.from_hex(mshex)
    encoded_json = '{"code":"example.tld","flg":192,"ver":3}'
    json_hash = OpenSSL::Digest::SHA256.digest(encoded_json)
    master_key = OpenSSL::PKCS5.pbkdf2_hmac(ms, salt, 4096, 32,
                                            OpenSSL::Digest::SHA256.new)
    g1 = Daniel::PasswordGenerator::GeneratorVersion1.new(ms)
    seed = g1.send(:hkdf_expand, master_key, '1:seed', 32)
    mac_key = g1.send(:hkdf_expand, master_key, '1:mac', 32)
    bytegen = Daniel::ByteGenerator.new(seed, json_hash)
    byteseq = Daniel::Util.to_binary(bytegen.random_bytes(1024)[0...len])
    expect(byteseq).to eq seq

    rem = gen.reminder('example.tld', params)
    m = /^.{16}(.*)\.([^.]+)example.tld$/.match rem
    jwt_content = m[1]
    mac = Daniel::Util.from_url64(m[2])
    computed = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, mac_key,
                                    jwt_content)
    expect(computed).to eq mac
  end

  it 'should generate expected byte sequence from parameters' do
    (0..1).each do |fv|
      gen = Daniel::PasswordGenerator.new('foobar', fv)
      params = Daniel::Parameters.new(0xc0, 20, 3, :iterations => 4096,
                                                   :format_version => 1,
                                                   :salt => 'sodium chloride')
      expect(gen.generate('example.tld', params)).to eq byte_sequence
    end
  end

  it 'should generate expected reminders' do
    (0..1).each do |fv|
      gen = Daniel::PasswordGenerator.new('foobar', fv)
      params = Daniel::Parameters.new(0xc0, 20, 3, :iterations => 4096,
                                                   :format_version => 1,
                                                   :salt => 'sodium chloride')
      rem = gen.reminder('example.tld', params)
      expect(rem).to eq reminder
    end
  end

  it 'should generate passwords from reminders' do
    (0..1).each do |fv|
      gen = Daniel::PasswordGenerator.new('foobar', fv)
      seq = gen.generate_from_reminder(reminder)
      expect(seq).to eq byte_sequence
    end
  end

  it 'should generate passwords from all-zero reminders' do
    (0..1).each do |fv|
      gen = Daniel::PasswordGenerator.new('foobar', fv)
      seq = gen.generate_from_reminder(zero_reminder)
      expect(seq).to eq byte_sequence
    end
  end

  it 'should validate MAC on reminders' do
    gen = Daniel::PasswordGenerator.new('foobar', 1)
    expect { gen.generate_from_reminder(reminder) }.not_to raise_error

    rem = reminder.sub(/...example.tld$/, 'abcexample.tld')
    error = Daniel::JWTValidationError
    expect { gen.generate_from_reminder(rem) }.to raise_error error
  end
end

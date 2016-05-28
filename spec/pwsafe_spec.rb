#!/usr/bin/ruby
# encoding: UTF-8

require File.join(File.dirname(__FILE__), 'spec_helper')

if RUBY_ENGINE != 'opal'
  require 'daniel/export/pwsafe'

  describe Daniel::Export::PasswordSafe do
    # The generated file with the below hash has been tested on Password Gorilla
    # and it does contain a single valid entry containing the correct password.
    it 'should produce valid PasswordSafe v3 files' do
      pass = 'foobar'
      io = StringIO.new('', 'w')
      pwsafe = Daniel::Export::PasswordSafe.new(pass, io,
                                                :salt => "\x00" * 32)
      gen = Daniel::PasswordGenerator.new(pass)
      pwsafe.add_entry(gen, '72eb36021000example.tld')
      pwsafe.finish
      hash = 'bd6b6cf78526aee94407e2e4ddfcbfffbc5ca5ae56be2239c5ef7982645edaed'
      expect(OpenSSL::Digest::SHA256.hexdigest(io.string)).to eq hash
    end

    it 'should produce valid PasswordSafe v3 files with usernames' do
      pass = 'foobar'
      io = StringIO.new('', 'w')
      pwsafe = Daniel::Export::PasswordSafe.new(pass, io,
                                                :salt => "\x00" * 32)
      gen = Daniel::PasswordGenerator.new(pass)
      pwsafe.add_entry(gen, '72eb36021000example.tld')
      pwsafe.add_entry(gen, '72eb36021000pass:jdoe%40nic.tld@example.com')
      pwsafe.finish
      hash = '8ab2ede934952e6ba99cab58fcedf8e02be144f135ae561e9785fa118270b3e6'
      expect(OpenSSL::Digest::SHA256.hexdigest(io.string)).to eq hash
    end
  end
end

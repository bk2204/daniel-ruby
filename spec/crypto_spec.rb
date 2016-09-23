#!/usr/bin/ruby
# encoding: UTF-8

require 'spec_helper'

# This test is designed not to test the built-in implementations, but the Opal
# polyfills.  It should, however, work on all Ruby implementations.
describe OpenSSL::Digest::SHA256 do
  it 'should produce the right digest of an empty string' do
    d = OpenSSL::Digest::SHA256.new
    expect(Daniel::Util.to_hex(d.digest)).to eq \
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  end

  it 'should produce the right digest of a Unicode string' do
    if ::RUBY_ENGINE == 'opal'
      pending 'Opal converting strings to bytes properly'
    end
    d = OpenSSL::Digest::SHA256.new
    d << 'La '
    d << 'république française'
    expect(Daniel::Util.to_hex(d.digest)).to eq \
      '0183a068b264ef517bc7e5cb7e7528cf6ef9a811a0e298d8162c56f6b4d094c6'
  end

  it 'should respond to #update' do
    d = OpenSSL::Digest::SHA256.new
    d.update 'a'
    d.update 'b'
    d.update 'c'
    expect(Daniel::Util.to_hex(d.digest)).to eq \
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
  end

  it 'should be able to perform one-pass hashing' do
    digest = OpenSSL::Digest::SHA256.digest('abc')
    expect(Daniel::Util.to_hex(digest)).to eq \
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
  end
end

describe OpenSSL::HMAC do
  it 'should produce the right MAC of dummy data' do
    d = OpenSSL::HMAC.new("\x00" * 32, OpenSSL::Digest::SHA256.new)
    expect(Daniel::Util.to_hex(d.digest)).to eq \
      'b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad'
  end

  it 'should produce the right MAC of dummy data' do
    if ::RUBY_ENGINE == 'opal'
      pending 'Opal converting strings to bytes properly'
    end
    d = OpenSSL::HMAC.new('abcd', OpenSSL::Digest::SHA256.new)
    d << 'La '
    d << 'république française'
    expect(Daniel::Util.to_hex(d.digest)).to eq \
      '485ec7b099a58c55a1f2d9a44f8e3e1061cb43cdde39a2d417478e05c7fa140a'
  end

  it 'should respond to #update' do
    d = OpenSSL::HMAC.new('abcd', OpenSSL::Digest::SHA256.new)
    d.update 'a'
    d.update 'b'
    d.update 'c'
    expect(Daniel::Util.to_hex(d.digest)).to eq \
      '2f4f5517ecf77837d4c87cd224a44fb44b0551a67805a61cca91f9c518a57223'
  end

  it 'should be able to perform one-pass MAC' do
    digest = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, 'abcd', 'abc')
    expect(Daniel::Util.to_hex(digest)).to eq \
      '2f4f5517ecf77837d4c87cd224a44fb44b0551a67805a61cca91f9c518a57223'
  end

  it 'should produce binary strings' do
    digest = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, 'abcd', 'abc')
    if Daniel::Version.smart_implementation?
      expect(digest.encoding).to eq Encoding::ASCII_8BIT
    end
  end
end

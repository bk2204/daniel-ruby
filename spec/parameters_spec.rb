#!/usr/bin/ruby
# encoding: UTF-8

require 'spec_helper'

describe Daniel::Parameters do
  it 'compares equal when default values given' do
    p = Daniel::Parameters.new
    expect(p).to eq Daniel::Parameters.new
  end

  it 'compares equal when explicitly-specified values given' do
    p = Daniel::Parameters.new(20, 8, 5)
    expect(p).to eq Daniel::Parameters.new(20, 8, 5)
  end

  it 'does not compare equal when any values differ' do
    p = Daniel::Parameters.new(20, 8, 5)
    expect(p).not_to eq Daniel::Parameters.new(21, 8, 5)
    expect(p).not_to eq Daniel::Parameters.new(20, 9, 5)
    expect(p).not_to eq Daniel::Parameters.new(20, 8, 4)
    expect(p).not_to eq Daniel::Parameters.new(20, 8, 5, :format_version => 1)
    expect(p).not_to eq Daniel::Parameters.new(20, 8, 5, :salt => 'bob')
  end

  it 'allows setting arbitrary bytes and existing passwords together' do
    p = Daniel::Parameters.new(0xa0, 16, 0)
    expect(p.flags).to eq 0xa0
  end

  it 'clears other symbol bits with arbitrary bytes flag' do
    p = Daniel::Parameters.new(0x84, 16, 0)
    expect(p.flags).to eq 0x80
  end

  it 'clears negated symbol bits with existing passwords flag' do
    p = Daniel::Parameters.new(0x24, 16, 0)
    expect(p.flags).to eq 0x20
  end

  it 'clears negated symbol bits with bytes and existing flags' do
    p = Daniel::Parameters.new(0xa4, 16, 0)
    expect(p.flags).to eq 0xa0
  end

  it 'defaults to having a version of 0' do
    expect(Daniel::Parameters.new.version).to eq 0
  end

  it 'defaults to having a length of 16' do
    expect(Daniel::Parameters.new.length).to eq 16
  end

  it 'defaults to having flags of 2' do
    constant = Daniel::Flags::NO_SPACES
    expect(Daniel::Parameters.new.flags).to eq 2
    expect(Daniel::Parameters.new.flags).to eq constant
  end

  it 'defaults to having a format version of 0' do
    expect(Daniel::Parameters.new.format_version).to eq 0
  end

  it 'sets the EXPLICIT_VERSION flag when using non-zero format version' do
    constant = Daniel::Flags::EXPLICIT_VERSION
    p = Daniel::Parameters.new(20, 8, 5, :format_version => 1)
    expect(p.flags).to eq 20 | constant
    expect(p.flags & constant).to eq constant
    p = Daniel::Parameters.new(20, 8, 5, :format_version => 1)
    p.flags = 0x0e
    expect(p.flags).to eq 0x4e
    expect(p.flags & constant).to eq constant
  end

  it 'defaults to having no salt' do
    expect(Daniel::Parameters.new.salt).to be nil
  end

  it 'accepts a salt' do
    p = Daniel::Parameters.new
    p.salt = 'bob'
    expect(p.salt).to eq Daniel::Util.to_binary('bob')
  end

  it 'accepts an empty salt' do
    p = Daniel::Parameters.new
    p.salt = ''
    expect(p.salt).to be nil
  end
end

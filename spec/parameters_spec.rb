#!/usr/bin/ruby
# encoding: UTF-8

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

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

  it 'defaults to having a version of 0' do
    expect(Daniel::Parameters.new.version).to eq 0
  end

  it 'defaults to having a length of 16' do
    expect(Daniel::Parameters.new.length).to eq 16
  end

  it 'defaults to having flags of 10' do
    constant = Daniel::Flags::NO_SPACES | Daniel::Flags::NO_SYMBOLS_OTHER
    expect(Daniel::Parameters.new.flags).to eq 10
    expect(Daniel::Parameters.new.flags).to eq constant
  end

  it 'defaults to having a format version of 0' do
    expect(Daniel::Parameters.new.format_version).to eq 0
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
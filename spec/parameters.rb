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
  end
end

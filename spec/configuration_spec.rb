#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'stringio'

describe Daniel::Configuration do
  it 'should default to the built-in defaults' do
    c = Daniel::Configuration.new
    expect(c.parameters(:default)).to eq Daniel::Parameters.new
    expect(c.passphrase(:default)).to be nil
  end

  it 'should load YAML data' do
    pending "Opal doesn't support YAML yet" if ::RUBY_ENGINE == 'opal'

    data = <<-EOM.gsub(/^\s{4}/, '')
    ---
    presets:
        default:
            salt: !!binary "c29kaXVtIGNobG9yaWRl"
            flags: 0x5e
            format-version: 1
            iterations: 12345
            version: 3
            length: 12
        throwaway:
            flags: 0x08
            format-version: 0
            version: 45
            length: 20
            passphrase: "bob's your uncle"
    EOM
    c = Daniel::Configuration.new(StringIO.new(data, 'r'))
    p = Daniel::Parameters.new(0x5e, 12, 3, :salt => 'sodium chloride',
                                            :format_version => 1,
                                            :iterations => 12_345)
    expect(c.parameters(:default)).to eq p
    expect(c.passphrase(:default)).to be nil
    p = Daniel::Parameters.new(0x08, 20, 45)
    expect(c.parameters(:throwaway)).to eq p
    expect(c.passphrase(:throwaway)).to eq "bob's your uncle"
  end
end

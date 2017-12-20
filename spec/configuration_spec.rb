require 'spec_helper'
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
        example:
            salt: !!binary "c29kaXVtIGNobG9yaWRl"
            flags: 0x1e
            format-version: 1
            iterations: 12345
            version: 3
            length: 12
            anonymous: true
    EOM
    c = Daniel::Configuration.new(StringIO.new(data, 'r'))
    p = Daniel::Parameters.new(0x5e, 12, 3, :salt => 'sodium chloride',
                                            :format_version => 1,
                                            :iterations => 12_345)
    p2 = p.dup
    p2.anonymous = true
    expect(c.parameters(:default)).to eq p
    expect(c.passphrase(:default)).to be nil
    expect(c.parameters(:example)).to eq p2
    expect(c.passphrase(:example)).to be nil
    p = Daniel::Parameters.new(0x08, 20, 45)
    expect(c.parameters(:throwaway)).to eq p
    expect(c.passphrase(:throwaway)).to eq "bob's your uncle"
  end

  it 'should produce random salt if requested' do
    pending "Opal doesn't support YAML yet" if ::RUBY_ENGINE == 'opal'

    data = <<-EOM.gsub(/^\s{4}/, '')
    ---
    presets:
        default:
            random-salt: 16
            flags: 0x5e
            format-version: 1
            iterations: 12345
            version: 3
            length: 12
    EOM
    salts = Array.new(5) do
      c = Daniel::Configuration.new(StringIO.new(data, 'r'))
      c.parameters(:default).salt
    end
    expect(salts.uniq.length).to eq 5
    salts.each { |s| expect(s.length).to eq 16 }
  end
end

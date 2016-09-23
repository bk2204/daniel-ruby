#!/usr/bin/ruby
# encoding: UTF-8

require 'spec_helper'

# These test cases are from RFC 5869.
describe Daniel::PasswordGenerator::GeneratorVersion1 do
  [
    [
      '0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b',
      '000102030405060708090a0b0c',
      'f0f1f2f3f4f5f6f7f8f9',
      '077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5',
      '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf' \
        '34007208d5b887185865'
    ],
    [
      Daniel::Util.to_hex((0x00..0x4f).to_a.pack('C*')),
      Daniel::Util.to_hex((0x60..0xaf).to_a.pack('C*')),
      Daniel::Util.to_hex((0xb0..0xff).to_a.pack('C*')),
      '06a6b88c5853361a06104c9ceb35b45cef760014904671014a193f40c15fc244',
      'b11e398dc80327a1c8e7f78c596a49344f012eda2d4efad8a050cc4c19afa97c' \
        '59045a99cac7827271cb41c65e590e09da3275600c2f09b8367793a9aca3db71' \
        'cc30c58179ec3e87c14c01d5c1f3434f1d87'
    ],
    [
      '0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b',
      nil,
      '',
      '19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04',
      '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d' \
        '9d201395faa4b61a96c8'
    ]
  ].each_with_index do |(ikm, salt, info, prk, okm), i|
    # This just tests that our testcases are generally complete.
    it "should have correct data for test case #{i + 1}" do
      s = salt ? Daniel::Util.from_hex(salt) : "\x00" * 32
      key = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, s,
                                 Daniel::Util.from_hex(ikm))
      expect(key).to eq Daniel::Util.from_hex(prk)
    end

    it "should produce the expected PRK for test case #{i + 1}" do
      expected = Daniel::Util.from_hex(okm)
      gen = Daniel::PasswordGenerator::GeneratorVersion1.new('')
      result = gen.send(:hkdf_expand, Daniel::Util.from_hex(prk),
                        Daniel::Util.from_hex(info), expected.length)
      expect(result).to eq expected
    end
  end
end

#!/usr/bin/ruby
# encoding: UTF-8

require File.join(File.dirname(__FILE__), 'spec_helper')

if RUBY_ENGINE != 'opal'
  require 'daniel/bytegen'

  describe Daniel::ByteGenerator do
    # These test vectors come from the NIST DRBG test vectors, available at
    # http://csrc.nist.gov/groups/STM/cavp/documents/drbg/drbgtestvectors.zip.
    # The vectors used are the SHA-256 HMAC_DRBG vectors from the no-reseed set.
    # More vectors can be added later, but this seems sufficient at the moment
    # to ensure proper implementation.
    [
      [
        'ca851911349384bffe89de1cbdc46e6831e44d34a4fb935ee285dd14b71a7488',
        '659ba96c601dc69fc902940805ec0ca8',
        'e528e9abf2dece54d47c7e75e5fe302149f817ea9fb4bee6f4199697d04d5b89' \
          'd54fbb978a15b5c443c9ec21036d2460b6f73ebad0dc2aba6e624abf07745bc1' \
          '07694bb7547bb0995f70de25d6b29e2d3011bb19d27676c07162c8b5ccde0668' \
          '961df86803482cb37ed6d5c0bb8d50cf1f50d476aa0458bdaba806f48be9dcb8'
      ],
      [
        '79737479ba4e7642a221fcfd1b820b134e9e3540a35bb48ffae29c20f5418ea3',
        '3593259c092bef4129bc2c6c9e19f343',
        'cf5ad5984f9e43917aa9087380dac46e410ddc8a7731859c84e9d0f31bd43655' \
          'b924159413e2293b17610f211e09f770f172b8fb693a35b85d3b9e5e63b1dc25' \
          '2ac0e115002e9bedfb4b5b6fd43f33b8e0eafb2d072e1a6fee1f159df9b51e6c' \
          '8da737e60d5032dd30544ec51558c6f080bdbdab1de8a939e961e06b5f1aca37'
      ]
    ].each_with_index do |(hsalt, hsecret, houtput), i|
      it "passes test vector #{i}" do
        gen = Daniel::ByteGenerator.new(Daniel::Util.from_hex(hsecret),
                                        Daniel::Util.from_hex(hsalt))
        gen.random_bytes(houtput.length / 2)
        output = gen.random_bytes(houtput.length / 2)
        expect(Daniel::Util.to_hex(output)).to eq houtput
      end
    end

    it 'generates valid v4 UUIDs' do
      gen = Daniel::ByteGenerator.new('example secret', "\x01\x02" * 16)
      100.times do
        uuid = gen.uuid
        pat = /\A[0-9a-f]{8}-
                 [0-9a-f]{4}-
                 4[0-9a-f]{3}-
                 [89ab][0-9a-f]{3}-
                 [0-9a-f]{12}\z/x
        expect(uuid).to match pat
      end
    end
  end
end

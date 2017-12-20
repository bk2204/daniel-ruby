require 'spec_helper'

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
    ],
    [
      'b340907445b97a8b589264de4a17c0bea11bb53ad72f9f33297f05d2879d898d',
      '65cb27735d83c0708f72684ea58f7ee5',
      '75183aaaf3574bc68003352ad655d0e9ce9dd17552723b47fab0e84ef903694a' \
        '32987eeddbdc48efd24195dbdac8a46ba2d972f5808f23a869e71343140361f5' \
        '8b243e62722088fe10a98e43372d252b144e00c89c215a76a121734bdc485486' \
        'f65c0b16b8963524a3a70e6f38f169c12f6cbdd169dd48fe4421a235847a23ff'
    ],
    [
      '8e159f60060a7d6a7e6fe7c9f769c30b98acb1240b25e7ee33f1da834c0858e7',
      'c39d35052201bdcce4e127a04f04d644',
      '62910a77213967ea93d6457e255af51fc79d49629af2fccd81840cdfbb491099' \
        '1f50a477cbd29edd8a47c4fec9d141f50dfde7c4d8fcab473eff3cc2ee9e7cc9' \
        '0871f180777a97841597b0dd7e779eff9784b9cc33689fd7d48c0dcd341515ac' \
        '8fecf5c55a6327aea8d58f97220b7462373e84e3b7417a57e80ce946d6120db5'
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
      h = '[0-9a-f]'
      pat = /^#{h}{8}-#{h}{4}-4#{h}{3}-[89ab]#{h}{3}-#{h}{12}$/
      expect(uuid).to match pat
    end
  end
end

require 'native'
require 'daniel/opal/sjcl.js'
require 'daniel/opal/aes.js'
require 'daniel/opal/bitArray.js'
require 'daniel/opal/codecBytes.js'
require 'daniel/opal/codecHex.js'
require 'daniel/opal/codecString.js'
require 'daniel/opal/hmac.js'
require 'daniel/opal/pbkdf2.js'
require 'daniel/opal/sha256.js'

module Daniel
  # Miscellaneous utilities.
  class Util
    # Convert a String to a bitArray.
    def self.to_bit_array(s)
      Native(`sjcl.codec.bytes.toBits(#{s.bytes})`)
    end

    # Convert a bitArray to a String.
    def self.from_bit_array(bits)
      Daniel::Util.from_hex(`sjcl.codec.hex.fromBits(#{bits})`)
    end
  end

  # A simple implementation of counter mode for ciphers with 16-byte blocks.
  class CounterMode
    def initialize(cipher, iv)
      @cipher = cipher
      @iv = iv
    end

    def encrypt(data)
      len = data.length
      s = ''
      (len / 16).ceil.times do
        cur, data = data[0..15], data[16..-1]
        buf = @cipher.encrypt(Daniel::Util.to_bit_array(@iv))
        s += xor(Daniel::Util.from_bit_array(buf)[0, cur.length], cur)
        increment
      end
      s
    end

    private

    def increment
      iv = @iv.bytes.reverse
      offset = 0
      while offset < 16
        iv[offset] += 1
        break unless iv[offset] == 256
        iv[offset] = 0
        offset += 1
      end
      @iv = iv.reverse.map(&:chr).join('')
    end

    def xor(a, b)
      a.bytes.zip(b.bytes).map { |p| (p[0] ^ p[1]).chr }.join('')
    end
  end
end

module OpenSSL
  module Cipher
    # AES polyfill using sjcl.
    class AES
      def initialize(keylen, mode)
        fail Daniel::Exception, 'invalid mode' unless mode == :CTR
        @keylen = keylen
      end

      def encrypt
      end

      def key=(key)
        @key = Daniel::Util.to_bit_array(key)
      end

      def iv=(iv)
        fail Daniel::Exception, 'need key before IV' unless @key
        @aes = Native(`new sjcl.cipher.aes(#{@key.to_n})`)
        @ctr = Daniel::CounterMode.new(@aes, iv[0, 16])
      end

      def update(input)
        @ctr.encrypt(input)[0, input.length]
      end
    end
  end

  module Digest
    # SHA-256 polyfill using sjcl.
    class SHA256
      def initialize
        @jsobj = Native(`new sjcl.hash.sha256()`)
      end

      def update(data)
        @jsobj.update(Daniel::Util.to_bit_array(data).to_n)
      end

      def digest
        Daniel::Util.from_bit_array(@jsobj.finalize)
      end
    end
  end

  # PBKDF2 polyfill using sjcl.
  module PKCS5
    def self.pbkdf2_hmac(pass, salt, iter, keylen, _digest)
      fail Daniel::Exception, 'invalid length' unless keylen == 32
      pass, salt = [pass, salt].map { |s| Daniel::Util.to_bit_array(s) }
      data = Native(`sjcl.misc.pbkdf2(#{pass.to_n}, #{salt.to_n}, #{iter})`)
      Daniel::Util.from_bit_array(data)
    end
  end
end

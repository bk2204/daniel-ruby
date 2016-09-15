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
      s = Daniel::Util.to_binary(s)
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
      s = Daniel::Util.to_binary('')
      (len / 16).ceil.times do
        chunk, data = encrypt_block(data)
        s += chunk
      end
      Daniel::Util.to_binary(s)
    end

    private

    def encrypt_block(data)
      cur = data[0..15]
      buf = @cipher.encrypt(Daniel::Util.to_bit_array(@iv))
      s = xor(Daniel::Util.from_bit_array(buf)[0, cur.length], cur)
      increment
      [s, data[16..-1]]
    end

    def increment
      iv = Daniel::Util.to_binary(@iv).bytes.reverse
      offset = 0
      while offset < 16
        iv[offset] += 1
        break unless iv[offset] == 256
        iv[offset] = 0
        offset += 1
      end
      @iv = iv.reverse.map { |c| Daniel::Util.to_chr(c) }.join
    end

    def xor(a, b)
      a, b = [a, b].map { |x| Daniel::Util.to_binary(x) }
      v = a.bytes.zip(b.bytes).map do |p|
        Daniel::Util.to_chr(p[0] ^ p[1])
      end
      Daniel::Util.to_binary(v.join)
    end
  end
end

module OpenSSL
  module Cipher
    # AES polyfill using sjcl.
    class AES
      def initialize(keylen, mode)
        raise Daniel::Exception, 'invalid mode' unless mode == :CTR
        @keylen = keylen
      end

      def encrypt
      end

      def key=(key)
        @key = Daniel::Util.to_bit_array(key)
      end

      def iv=(iv)
        raise Daniel::Exception, 'need key before IV' unless @key
        @aes = Native(`new sjcl.cipher.aes(#{@key.to_n})`)
        @ctr = Daniel::CounterMode.new(@aes, iv[0, 16])
      end

      def update(input)
        input = Daniel::Util.to_binary(input)
        Daniel::Util.to_binary(@ctr.encrypt(input)[0, input.length])
      end

      def final
        ''
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
        self
      end

      alias :<< :update

      def digest
        Daniel::Util.from_bit_array(@jsobj.finalize)
      end

      def self.digest(s)
        obj = new
        obj << s
        obj.digest
      end
    end
  end

  # This only implements HMAC-SHA-256, since that's all we use.
  class HMAC
    def initialize(key, _digest)
      k = Daniel::Util.to_bit_array(key).to_n
      @jsobj = Native(`new sjcl.misc.hmac(#{k})`)
    end

    def update(data)
      @jsobj.update(Daniel::Util.to_bit_array(data).to_n)
      self
    end

    alias :<< :update

    def digest
      Daniel::Util.from_bit_array(@jsobj.digest)
    end

    def self.digest(digest, k, v)
      obj = new(k, digest)
      obj << v
      obj.digest
    end
  end

  # PBKDF2 polyfill using sjcl.
  module PKCS5
    def self.pbkdf2_hmac(pass, salt, iter, keylen, _digest)
      raise Daniel::Exception, 'invalid length' unless keylen == 32
      pass, salt = [pass, salt].map { |s| Daniel::Util.to_bit_array(s) }
      data = Native(`sjcl.misc.pbkdf2(#{pass.to_n}, #{salt.to_n}, #{iter})`)
      Daniel::Util.from_bit_array(data)
    end
  end
end

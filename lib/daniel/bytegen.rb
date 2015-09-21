require 'daniel'

# A password generation tool.
module Daniel
  # A PRNG based on a secret and a salt.
  #
  # Uses the HMAC_DRBG as specified in NIST SP800-90A.  This class is required
  # so that the unit tests can produce reproducible output while still
  # generating secure output by using a salt from SecureRandom each time.  This
  # is essentially the technique used by RFC 6979.
  class ByteGenerator
    # Create a new ByteGenerator.
    #
    # @param secret [String] A secret, which may be low entropy (e.g. a
    #   password)
    # @param salt [String] A 32-bit pseudorandom salt, which should be different
    #   for each instantiation.
    def initialize(secret, salt)
      @k = "\x00" * 32
      @v = "\x01" * 32
      update(salt + secret)
    end

    def random_bytes(n)
      buffer = Util.to_binary('')
      while buffer.bytesize < n
        @v = hmac(@k, @v)
        buffer << @v
      end
      update
      buffer[0, n]
    end

    # Generate a random version 4 UUID.
    def uuid
      buffer = random_bytes(16)
      buffer[6] = Util.to_chr((buffer[6].ord & 0x0f) | 0x40)
      buffer[8] = Util.to_chr((buffer[8].ord & 0x3f) | 0x80)
      hex = Util.to_hex(buffer)
      [0..7, 8..11, 12..15, 16..19, 20..31].map { |r| hex[r] }.join('-')
    end

    protected

    def update(seed = nil)
      @k = hmac(@k, @v + "\x00" + (seed || ''))
      @v = hmac(@k, @v)
      return if seed.nil?
      @k = hmac(@k, @v + "\x01" + seed)
      @v = hmac(@k, @v)
    end

    def hmac(k, v)
      OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, k, v)
    end
  end
end

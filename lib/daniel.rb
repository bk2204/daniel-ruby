#!/usr/bin/ruby
# daniel - a password generator
#
# Copyright © 2013–2016 brian m. carlson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

RUBY_ENGINE = 'unknown' unless defined? RUBY_ENGINE
if RUBY_ENGINE == 'opal'
  require 'opal'
  require 'daniel/opal'
else
  require 'openssl'
  require 'securerandom'
end
require 'base64'
require 'json'
require 'set'
require 'yaml'

# A password generation tool.
module Daniel
  # The class from which all Daniel exceptions derive.
  class Exception < StandardError
  end

  # An exception indicating an invalid parameter value.
  class InvalidParametersError < Exception
  end

  # An exception indicating an invalid reminder string.
  class InvalidReminderError < Exception
  end

  # An exception indicating an invalid JSON Web Token.
  class InvalidJWTError < Exception
  end

  # An exception indicating an JSON Web Token failed validation (MAC check).
  class JWTValidationError < Exception
  end

  # An exception indicating that the required data is not present.
  class MissingDataError < Exception
  end

  # An exception indicating a checksum mismatch.
  class ChecksumMismatchError < InvalidReminderError
    def initialize(actual, expected)
      super("Checksum mismatch (#{actual} != #{expected})")
    end
  end

  # The version number of Daniel.
  class Version
    def self.to_s
      '0.2.0'
    end

    # Are we dealing with a reasonably modern and feature-complete
    # implementation?
    def self.smart_implementation?
      ::RUBY_VERSION.to_f > 1.8
    end
  end

  # Utility functions.
  class Util
    def self.to_hex(s)
      to_binary(s).unpack('H*')[0]
    end

    def self.from_hex(s)
      result = [s].pack('H*')
      to_binary(result)
    end

    def self.to_base64(s)
      to_binary(Base64.encode64(s).delete("\r\n"))
    end

    def self.from_base64(s)
      Base64.decode64(s)
    end

    def self.to_url64(s)
      to_base64(s).tr('/+', '_-').delete("=\r\n")
    end

    def self.from_url64(s)
      s += case s.length & 3
           when 0
             ''
           when 2
             '=='
           when 3
             '='
           end
      from_base64(s.tr('-_', '+/'))
    end

    # Convert a byte to a character.
    def self.to_chr(b)
      Version.smart_implementation? ? b.chr('BINARY') : b.chr
    end

    def self.to_binary(s)
      Version.smart_implementation? ? s.force_encoding('BINARY') : s
    end

    # Compare strings a and b in constant time.
    def self.constant_equal?(a, b)
      diff = 0
      a, b = [a, b].map { |s| Util.to_binary(s) }
      # Constant time comparison.
      a.bytes.to_a.zip(b.bytes.to_a).each do |ab, bb|
        diff |= ab ^ bb
      end
      diff == 0
    end
  end

  # Flag constants and conversion functions.
  class Flags
    NO_NUMBERS = 0x01
    NO_SPACES = 0x02
    NO_SYMBOLS_TOP = 0x04
    NO_SYMBOLS_OTHER = 0x08
    NO_LETTERS = 0x10
    SYMBOL_MASK_NEGATED = 0x1f
    SYMBOL_MASK = 0x9f
    REPLICATE_EXISTING = 0x20
    EXPLICIT_VERSION = 0x40
    ARBITRARY_BYTES = 0x80
    IMPLEMENTED_MASK = 0xff

    # Compute a flag value from a number or string.
    #
    # @param text [String, Fixnum] the value to convert to a flags value
    # @return [Fixnum] the computed value.
    #
    # Accepts a value either as an existing integer; a string containing a
    # decimal, octal, or hexadecimal number in C/Ruby format; or a string
    # containing characters representing the allowed symbols.
    #
    # This function computes only values that are part of {Flags::SYMBOL_MASK}.
    def self.mask_from_characters(text)
      if text.is_a?(Fixnum)
        return text
      elsif text =~ /^0[0-7]+$/
        return text.to_i(8)
      elsif text =~ /^\d+$/
        return text.to_i
      elsif text =~ /^0[xX][A-Fa-f0-9]+$/
        return text.to_i(16)
      else
        value = SYMBOL_MASK_NEGATED
        masks = {
          '0' => NO_NUMBERS,
          'A' => NO_LETTERS,
          'a' => NO_LETTERS,
          's' => NO_SPACES,
          ' ' => NO_SPACES,
          '!' => NO_SYMBOLS_TOP,
          ':' => NO_SYMBOLS_OTHER,
          '+' => NO_SYMBOLS_OTHER,
          '-' => NO_SYMBOLS_OTHER
        }
        masks.keys.each { |ch| value &= ~masks[ch] if text.include? ch }
        return value
      end
    end

    # Provide a human-readable description of a flags value.
    #
    # @param value [Integer] the flags value
    # @return [Array<String>] the list of strings representing the value
    def self.explain(value)
      flags = flag_names
      if value < 0 || value > ((1 << flags.length) - 1)
        fail InvalidParametersError, 'Invalid flags value'
      end
      result = []
      flags.each_with_index do |item, index|
        result << item if (value & (1 << index)) != 0
      end
      result
    end

    # Provide a human-readable list of possible flag values.
    #
    # @return [Array<String>] an ordered list of valid flag names.
    #
    # Transforms the constants in this class into an array of strings such that
    # the string with index i represents a flag with value 1 << i.  Constants
    # whose values are not a power of two are ignored.
    def self.flag_names
      flags = {}
      constants.each { |k| flags[k] = const_get(k) }
      pairs = flags.select { |_, v| (v & (v - 1)) == 0 }.sort_by { |_, v| v }
      pairs.map { |k, _| k.to_s.downcase.tr('_', '-') }
    end
  end

  # A set of characters which are acceptable in a generated password.
  class CharacterSet < ::Set
    # Create a new set of characters which are valid in a password
    #
    # @param options [Integer] a set of bit flags
    def initialize(options = Flags::NO_SPACES)
      super((options & Flags::ARBITRARY_BYTES) != 0 ? 0x00..0xff : 0x20..0x7e)
      m = {
        Flags::NO_NUMBERS => 0x30..0x39,
        Flags::NO_SPACES => [0x20],
        Flags::NO_SYMBOLS_TOP => '!@#$%^&*()'.each_byte,
        Flags::NO_SYMBOLS_OTHER => '"\'+,-./:;<=>?[\\]_`{|}~'.each_byte,
        Flags::NO_LETTERS => [(0x41..0x5a).to_a, (0x61..0x7a).to_a].flatten
      }
      m.each do |k, v|
        v.each { |x| delete(x) } if options & k != 0
      end
    end

    # Create a new CharacterSet from a text string representing valid flags.
    #
    # @return [CharacterSet] the set of valid characters
    #
    # Valid strings are those which can be passed to
    # {Flags.mask_from_characters}.
    def self.from_characters(text)
      new Flags.mask_from_characters(text)
    end
  end

  # The parameters affecting generation of a password.
  class Parameters
    attr_reader :flags, :length, :version, :salt, :format_version, :iterations

    def initialize(flags = 2, length = 16, version = 0, options = {})
      self.flags = flags
      @length = length
      @version = version
      self.salt = options[:salt]
      @format_version = options[:format_version] || 0
      @iterations = options[:iterations] || 1024
    end

    def flags=(flags)
      flags = Flags.mask_from_characters(flags)
      if (flags & ~Flags::IMPLEMENTED_MASK) != 0
        fail InvalidParametersError, format('Invalid flags value %08x', flags)
      end
      if (flags & (Flags::REPLICATE_EXISTING | Flags::ARBITRARY_BYTES)) != 0
        flags &= ~Flags::SYMBOL_MASK_NEGATED
      end
      @flags = flags
    end

    def length=(length)
      @length = length.to_i
    end

    def version=(version)
      @version = version.to_i
    end

    def salt=(salt)
      @salt = salt.nil? || salt.empty? ? nil : Util.to_binary(salt)
    end

    def format_version=(ver)
      @format_version = ver.to_i
    end

    def iterations=(iters)
      @iterations = iters.to_i
    end

    # Is this password an encrypted password?
    #
    # @return false if the password was generated by this tool, or true if this
    #   is a pre-existing password entered by the user that is stored encrypted
    def existing_mode?
      (@flags & Flags::REPLICATE_EXISTING) != 0
    end

    # Can the password contain arbitrary byte values?
    #
    # @return true if the password can contain arbitrary byte values, or false
    #   if it is limited to UTF-8 text only
    def binary?
      (@flags & Flags::ARBITRARY_BYTES) != 0
    end

    def ==(other)
      [:flags, :length, :version, :salt, :format_version].each do |m|
        return false unless method(m).call == other.method(m).call
      end
      true
    end

    alias_method :eql?, :==
  end

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
    # @param salt [String, nil] A 32-bit pseudorandom salt, which should be
    #   different for each instantiation.  If nil, generates a random value.
    def initialize(secret, salt = nil)
      salt = SecureRandom.random_bytes(32) if salt.nil?
      @k = Daniel::Util.to_binary("\x00" * 32)
      @v = Daniel::Util.to_binary("\x01" * 32)
      update(salt + secret)
    end

    def random_bytes(n)
      buffer = Util.to_binary('')
      while buffer.bytesize < n
        @v = hmac(@k, @v)
        buffer = Util.to_binary(buffer + @v)
      end
      update
      Util.to_binary(buffer)[0, n]
    end

    # Generate a random version 4 UUID.
    def uuid
      buffer = canonicalize_uuid Util.to_binary(random_bytes(16)).each_byte.to_a
      hex = buffer.map { |b| format('%02x', b) }.join
      [0..7, 8..11, 12..15, 16..19, 20..31].map { |r| hex[r] }.join('-')
    end

    protected

    def canonicalize_uuid(buffer)
      buffer[6] = (buffer[6] & 0x0f) | 0x40
      buffer[8] = (buffer[8] & 0x3f) | 0x80
      buffer
    end

    def update(seed = nil)
      seed = Daniel::Util.to_binary(seed) if seed
      @k = hmac(@k, @v + Daniel::Util.to_chr(0) + (seed || ''))
      @v = hmac(@k, @v)
      return if seed.nil?
      @k = hmac(@k, @v + Daniel::Util.to_chr(1) + seed)
      @v = hmac(@k, @v)
    end

    def hmac(k, v)
      OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, k, v)
    end
  end

  # A limited JSON Web Token implementation.
  #
  # This implementation only generates HMAC-SHA-256 tokens, and it requires that
  # all data be canonicalized (shortest possible JSON with keys sorted).
  class JWT
    HEADER = '{"alg":"HS256","kid":"%s","typ":"JWT"}'.freeze

    attr_reader :mac, :key_id, :serialized

    class << self
      protected

      def old_canonical_json(data)
        items = data.keys.sort { |a, b| a.to_s <=> b.to_s }.map do |k|
          dummy = { k.to_s => data[k] }
          JSON.generate(dummy)[1..-2]
        end
        "{#{items.join(',')}}"
      end
    end

    def self.parse(s, options = {})
      header, payload, mac = s.split('.').map { |t| Util.from_url64(t) }
      re = /^#{Regexp.escape(HEADER).sub('%s', "(\\d+:\\d+:[a-f0-9]+(:.*)?)")}$/
      m = re.match header
      fail InvalidJWTError, 'invalid JWT header' unless m
      new(payload, :mac => mac, :mac_key => options[:mac_key], :key_id => m[1],
                   :skip_verify => options[:skip_verify])
    end

    # Return a hash in canonical JSON form.
    #
    # The canonical JSON format is the shortest possible JSON representation
    # (i.e., no extraneous whitespace) with each object having its keys sorted.
    # Currently, this implementation does not operate recursively.
    #
    # @param data [Hash] the data to canonicalize
    # @return [String] a canonical JSON representation of data
    def self.canonical_json(data)
      if !Version.smart_implementation? || ::RUBY_ENGINE == 'opal'
        return old_canonical_json(data)
      end
      canonical = {}
      data.sort_by { |k, _| k }.each { |k, v| canonical[k] = v }
      JSON.generate(canonical)
    end

    def initialize(payload, options = {})
      @mac_key = options[:mac_key]
      @valid = false
      @mac = options[:mac]
      @key_id = options[:key_id]
      @skip_verify = options[:skip_verify]
      if payload.is_a? String
        @serialized = payload
        validate if @mac_key
      else
        @payload = payload
        @serialized = self.class.canonical_json(payload)
        @mac = compute_hmac unless @mac
      end
    end

    def valid?
      return @valid unless @valid.nil?
      validate
    rescue JWTValidationError
      false
    end

    def validate
      unless Daniel::Util.constant_equal?(compute_hmac, mac)
        fail JWTValidationError, 'MAC is incorrect'
      end
      @payload = check_canonical_object(@serialized) unless @payload
      @valid = true
      self
    end

    def mac_key=(key)
      @mac_key = key
      @valid = nil
    end

    def payload
      return check_canonical_object(@serialized) if @skip_verify
      validate unless @valid
      @payload
    end

    def to_s
      validate unless @valid
      [header, @serialized, @mac].map { |s| Util.to_url64(s) }.join('.')
    end

    protected

    def header
      HEADER % @key_id
    end

    def compute_hmac
      fail MissingDataError unless @mac_key
      hmac = OpenSSL::HMAC.new(@mac_key, OpenSSL::Digest::SHA256.new)
      hmac << [header, @serialized].map { |s| Util.to_url64(s) }.join('.')
      hmac.digest
    end

    def check_canonical_object(s)
      fail InvalidJWTError, 'overlong JWT' if s.length > 1024
      data = JSON.parse(s, :symbolize_names => 1)
      canon_json = self.class.canonical_json(data)
      fail InvalidJWTError, 'noncanonical data' if s != canon_json
      data
    end
  end

  # A parsed reminder value
  Reminder = Struct.new(:params, :checksum, :code, :mask, :options) do
    # A parser for reminder string values.
    #
    # This class is an implementation detail.  Use
    # {PasswordGenerator.parse_reminder} instead.
    class Parser
      def initialize(params, checksum)
        @params = params
        @checksum = checksum
      end

      def self.parse(s, options = {})
        klass, params, csum, args = parse_common_header(s)
        Reminder.new(*klass.new(params, csum).parse_version(args, options))
      end

      def self.parse_header(s)
        klass, params, csum, args = parse_common_header(s)
        klass.new(params, csum).parse_header(args)
      end

      class << self
        protected

        BER_PATTERN = '(?:(?:[89a-f][0-9a-f])*[0-9a-f][0-9a-f])'.freeze
        SUPPORTED_VERSIONS = (0..1).freeze

        def parse_common_header(rem)
          params = Parameters.new
          csum = rem[0..5]
          args = parse_ber(rem[6..-1])
          params.flags = args.shift
          version = (params.flags & Flags::EXPLICIT_VERSION) != 0 ? args[0] : 0
          unless SUPPORTED_VERSIONS.include? version
            fail InvalidReminderError, 'bad version'
          end
          [[Version0Parser, Version1Parser][version], params, csum, args]
        end

        def parse_ber(s)
          m = /^(#{BER_PATTERN}{3})(.*)$/.match(s)
          fail InvalidReminderError, 'Invalid reminder' unless m
          Util.from_hex(m[1]).unpack('w3') << m[2]
        end
      end
    end

    # A parser for version 0 reminder string values.
    #
    # This class is an implementation detail.  Use
    # {PasswordGenerator.parse_reminder} instead.
    class Version0Parser < Parser
      def parse_version(args, _options)
        @params.length, @params.version, code = *args
        code, mask = compute_mask(@params.flags, @params.length, code)
        [@params, @checksum, code, mask, {}]
      end

      def parse_header(args)
        parse_version(args, {})[0]
      end

      protected

      def compute_mask(flags, length, code)
        return [code, nil] if (flags & Flags::REPLICATE_EXISTING) == 0

        m = /^([0-9a-f]{#{2 * length}})(.*)$/.match(code)
        unless m
          fail InvalidReminderError, 'Flags set to existing but mask missing'
        end
        [m[2], Util.from_hex(m[1])]
      end
    end

    # A parser for version 1 reminder string values.
    #
    # This class is an implementation detail.  Use
    # {PasswordGenerator.parse_reminder} instead.
    class Version1Parser < Parser
      def parse_version(args, options)
        len, remaining = args[1..-1]
        parse_jwt(remaining[0...len], remaining[len..-1], options)
      end

      def parse_header(args)
        len, remaining = args[1..-1]
        parse_jwt_header(remaining[0...len])
        @params
      end

      protected

      def validate_jwt(data, code)
        par = @params
        fail InvalidReminderError, 'invalid protocol' if par.format_version != 1
        fail InvalidReminderError, 'invalid flags' if data[:flg] != par.flags
        fail InvalidReminderError, 'invalid code' if data[:code] != code
        true
      end

      def parse_key_id(key_id)
        pver, iters, kcsum, salt = key_id.split(':')
        Reminder.compare_checksum(kcsum, @checksum)
        @params.format_version = pver.to_i
        @params.salt = Util.from_url64(salt.to_s)
        @params.iterations = iters.to_i
      end

      def parse_jwt_header(s, options = {})
        jwt = JWT.parse(s, options)
        options[:mac] = jwt.mac
        parse_key_id(jwt.key_id)
        jwt
      end

      def parse_jwt(s, code, options)
        jwt = parse_jwt_header(s, options)
        jwt.mac_key = options[:mac_key]
        data = jwt.payload
        validate_jwt(data, code)
        mask = data.key?(:msk) ? Util.from_url64(data[:msk]) : nil
        @params.length = data[:len]
        @params.version = data[:ver]
        [@params, @checksum, code, mask, options]
      end
    end

    # Parse a reminder into its constituent parts.
    #
    # This method does not validate the MAC on the reminder it generates.  Use
    # {PasswordGenerator.parse_reminder} instead.
    #
    # @param rem [String] the complete reminder string
    # @param options [Hash] options required to parse the parameters
    # @return [Reminder] the parsed set of parameters
    def self.parse(rem, options = {})
      return rem if rem.is_a? Reminder
      Reminder.new(*Parser.parse(rem, options))
    end

    def self.parse_header(rem)
      return rem.params if rem.is_a? Reminder
      Parser.parse_header(rem)
    end

    def self.compare_checksum(rem_csum, gen_csum)
      if rem_csum != gen_csum && rem_csum != '000000'
        fail ChecksumMismatchError.new(rem_csum, gen_csum)
      end
      true
    end

    # Additional options, if any.
    #
    # @return [Hash] the options or an empty Hash
    def options
      self[:options] || {}
    end

    # The MAC associated with this reminder.
    #
    # Only format version 1 reminders have a MAC.
    #
    # @return [String, nil] the MAC
    def mac
      options[:mac]
    end

    # Set the MAC key to validate this reminder.
    def mac_key=(key)
      options[:mac_key] = key
    end

    # The reminder in JWT form.
    #
    # Only format version 1 reminders can be represented in JWT form.
    #
    # @return [String, nil] the encoded JWT in compact serialization or nil
    def jwt
      return nil if params.format_version == 0
      data = {
        :flg => params.flags,
        :len => params.length,
        :ver => params.version,
        :code => code
      }
      data[:msk] = Util.to_url64(mask) if mask
      JWT.new(data, :mac => mac, :mac_key => mac_key, :key_id => key_id)
    end

    # Validate the MAC on the reminder.
    def validate
      token = jwt
      return unless token
      token.validate
    end

    # Convert this reminder to a string form.
    #
    # Calling {PasswordGenerator.parse_reminder} will convert the stringified
    # form back into an object.
    def to_s
      send("format_v#{params.format_version}")
    end

    def anonymous?
      checksum == '000000'
    end

    protected

    def key_id
      k = [params.format_version, params.iterations, checksum]
      k << Util.to_url64(params.salt) if params.salt
      k.join(':')
    end

    def mac_key
      options[:mac_key]
    end

    def format_v0
      p = params
      prefix([p.flags, p.length, p.version], mask) + code
    end

    def format_v1
      jwts = jwt.to_s
      prefix([params.flags, 1, jwts.length]) + jwts + code
    end

    def prefix(ints, mask = nil)
      checksum + Util.to_hex(ints.pack('w3') + mask.to_s)
    end
  end

  # Format a password or other text.
  class Formatter
    # Format a password in plain text.
    #
    # @return [String] the original string
    #
    # This function performs the identity transformation on the string.
    def self.plain(s)
      s
    end

    # Format a password in the Bubble Babble format.
    class BubbleBabble
      def initialize(s)
        @data = Util.to_binary(s).bytes.to_a
        @len = (@data.length / 2).to_i
      end

      def formatted
        format(tuples, partial)
      end

      protected

      attr_reader :data, :len

      def format_tuple(a, b, c, d = 0, e = 0)
        v = %w(a e i o u y)
        co = %w(b c d f g h k l m n p r s t v z x)
        [v[a], co[b], v[c], co[d], '-', co[e]]
      end

      def format(t, p)
        res = t.map { |x| format_tuple(*x) } + format_tuple(*p)[0..2]
        'x' + res.flatten.join('') + 'x'
      end

      def checksum # rubocop:disable Metrics/AbcSize
        return @checksum if @checksum
        k = []
        (len + 1).times do |i|
          k[i] = i == 0 ? 1 : (((k[i - 1] * 5) +
                               (data[i * 2 - 2] * 7 + data[i * 2 - 1])) % 36)
        end
        @checksum = k
      end

      def tuple(c, d1, d2)
        [
          (((d1 >> 6) & 3) + c) % 6,
          (d1 >> 2) & 15,
          ((d1 & 3) + (c / 6)) % 6,
          (d2 >> 4) & 15,
          (d2 & 15)
        ]
      end

      def partial
        cl = checksum[len]
        if data.length.even?
          [cl % 6, 16, cl / 6]
        else
          tuple(cl, data[-1], 0)[0..2]
        end
      end

      def tuples
        len.times.map do |i|
          tuple(checksum[i], data[i * 2], data[i * 2 + 1])
        end
      end
    end

    # Format a password in the Bubble Babble format.
    #
    # @return [String] the string converted to Bubble Babble format
    #
    # This function converts the string into the Bubble Babble encoding.  This
    # encoding provides the password in a human-pronounceable that provides a
    # small amount of redundancy against accidental corruption.
    def self.bubblebabble(s)
      BubbleBabble.new(s).formatted
    end
  end

  # Configuration data as read from the user's configuration file.
  class Configuration
    def initialize(file = nil)
      @presets = {
        'default' => { :params => Daniel::Parameters.new }
      }
      if file.nil?
        file = File.exist?(default_path) ? File.new(default_path, 'r') : nil
      end
      load_data(file)
    end

    def parameters(s)
      return nil unless @presets.key? s.to_s
      @presets[s.to_s][:params]
    end

    def passphrase(s)
      return nil unless @presets.key? s.to_s
      @presets[s.to_s][:passphrase]
    end

    protected

    def default_path
      config = ENV['XDG_CONFIG_HOME'] || File.join(ENV['HOME'], '.config')
      File.join(config, 'daniel', 'main.yaml')
    end

    def load_data(file)
      return if file.nil? || !defined?(YAML)
      data = ::YAML.load(file.read)
      return unless data['presets']
      data['presets'].each do |name, params|
        p = Daniel::Parameters.new
        [
          :flags, :version, :length, :format_version, :salt, :iterations
        ].each do |sym|
          val = data_from(params, sym)
          p.method(:"#{sym}=").call(val) if val
        end
        @presets[name] = { :params => p, :passphrase => params['passphrase'] }
      end
    end

    def data_from(params, sym)
      val = params[sym.to_s.tr('_', '-')]
      # Ruby 1.8 does this for binary.
      if val.respond_to?(:type_id) && val.type_id == 'binary'
        val = Daniel::Util.from_base64(val.value)
      end
      val
    end
  end

  # Generates a password or set of passwords.
  #
  # Note that passwords are returned as byte strings (encoding ASCII-8BIT).
  # Unless the DC::Flags::ARBITRARY_BYTES flag is set, the password should be
  # valid UTF-8.
  class PasswordGenerator
    # Generates version 0 passwords.
    #
    # This class is an implementation detail.
    class GeneratorVersion0 < PasswordGenerator
      def initialize(master_secret)
        setup
        @version = 0
        @master_secret = master_secret
      end

      def generate(code, params, mask = nil)
        flags = format('Flags 0x%08x: ', params.flags)
        version = format('Version 0x%08x: ', params.version)

        cipher = OpenSSL::Cipher::AES.new(256, :CTR)
        cipher.encrypt
        cipher.key = @master_secret
        cipher.iv = process_strings([@prefix, 'IV: ', flags, version, code],
                                    @master_secret)

        gen = generator_function(cipher)
        return generate_existing(gen, params, mask) if params.existing_mode?
        generate_default(gen, params)
      end

      def generator_function(cipher)
        buffer = ([0] * 32).pack('C*')
        lambda { cipher.update(buffer).bytes }
      end

      def reminder(code, params, mask = nil)
        Reminder.new(params, Util.to_hex(checksum), code, mask).to_s
      end

      def parse_reminder(reminder)
        Reminder.parse(reminder)
      end
    end

    # Generates version 1 passwords.
    #
    # This class is an implementation detail.
    class GeneratorVersion1 < PasswordGenerator
      def initialize(master_secret)
        setup
        @version = 1
        @master_secret = master_secret
        @keys = {}
      end

      def generate(code, params, mask = nil)
        seed = key_for(params, :seed)
        data = {
          :flg => params.flags,
          :ver => params.version,
          :code => code
        }
        salt = OpenSSL::Digest::SHA256.digest(JWT.canonical_json(data))
        prng = Daniel::ByteGenerator.new(seed, salt)

        gen = generator_function(prng)
        return generate_existing(gen, params, mask) if params.existing_mode?
        generate_default(gen, params)
      end

      def generator_function(prng)
        lambda { Daniel::Util.to_binary(prng.random_bytes(1024)).bytes }
      end

      def reminder(code, params, mask = nil)
        Reminder.new(params, Util.to_hex(checksum), code, mask,
                     :mac_key => key_for(params, :mac)).to_s
      end

      def parse_reminder(reminder)
        params = Reminder.parse_header(reminder)
        rem = Reminder.parse(reminder, :mac_key => key_for(params, :mac))
        rem
      end

      protected

      # Generate a key of length bytes based on the iteration count, salt (if
      # any), and the master secret.
      #
      # Uses PBKDF2-HMAC-SHA-256 to generate a master key, and then uses
      # HKDF-Expand to produce the required number of bytes.
      def key_for(params, id, length = 32)
        pset = {
          :iters => params.iterations,
          :salt => params.salt
        }
        @keys[pset] = { :master => master_key_for(params) } unless @keys[pset]
        return @keys[pset][id] if @keys[pset][id]
        @keys[pset][id] = hkdf_expand(@keys[pset][:master], "1:#{id}", length)
      end

      def master_key_for(params)
        OpenSSL::PKCS5.pbkdf2_hmac(@master_secret, params.salt.to_s,
                                   params.iterations, 32,
                                   OpenSSL::Digest::SHA256.new)
      end

      def hkdf_expand(prk, info, length)
        niters = (length / 32.0).ceil
        t = ['']
        (1..niters).each do |i|
          t << OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, prk,
                                    t[i - 1] + info.to_s + i.chr)
        end
        t.join[0...length]
      end
    end

    def initialize(pass, _version = 0)
      setup
      @master_secret = process_strings([@prefix, 'Master Secret: ', pass], '')
      klasses = [GeneratorVersion0, GeneratorVersion1]
      @impls = klasses.map { |c| c.new(@master_secret) }
    end

    def checksum
      return @checksum unless @checksum.nil?
      @checksum = compute_checksum
    end

    # Generate a mask for an existing password.
    #
    # @param code [String] the code to generate the mask for
    # @param params [Daniel::Parameters] the parameters
    # @param password [String] the existing password to generate the mask for
    #
    # The REPLICATE_EXISTING flag should be set in params.flags.
    #
    # Because of the way XOR works, if the mask argument is the password, this
    # function will return the mask.
    def generate_mask(code, params, password)
      fail InvalidParametersError, 'Invalid flags' unless params.existing_mode?
      generate(code, params, password)
    end

    # Generate a password.
    #
    # @param code [String] the code to generate the password for
    # @param params [Daniel::Parameters] the parameters
    # @param make [String, nil] the mask as a byte string or nil
    # @return [String] the generated password
    def generate(code, params, mask = nil)
      impl(params).generate(code, params, mask)
    end

    # Parse a reminder, validating it if necessary.
    #
    # @param rem [String] the reminder string
    # @return [Reminder] the reminder
    def parse_reminder(rem)
      params = Reminder.parse_header(rem)
      impl(params).parse_reminder(rem)
    end

    # Generate a password based on a reminder.
    #
    # @param reminder [String, Daniel::Reminder] the reminder
    # @return [String] the generated password
    def generate_from_reminder(reminder)
      rem = parse_reminder(reminder)
      computed = Util.to_hex(checksum)
      rem.class.compare_checksum(rem.checksum, computed)

      impl(rem).generate(rem.code, rem.params, rem.mask)
    end

    # Create a reminder based on the given parameters
    #
    # @param code [String] the code for the given reminder
    # @param params [Daniel::Parameters] the parameters for the given reminder
    # @param mask [String, nil] the mask for the given reminder, or nil
    # @return [String] the reminder
    def reminder(code, params, mask = nil)
      impl(params).reminder(code, params, mask)
    end

    protected

    # Get the implementation for a Reminder or Parameters object.
    def impl(selector)
      selector = selector.params if selector.is_a? Reminder
      @impls[selector.format_version]
    end

    def setup
      @prefix = format('DrewPassChart: Version 0x%08x: ', 0)
      @checksum = nil
    end

    def generate_existing(gen, parameters, mask)
      if parameters.length != mask.length
        fail InvalidParametersError, 'Invalid mask length'
      end
      result = []
      result += gen.call.to_a while result.length < parameters.length
      xor(mask, result[0...parameters.length])
    end

    def xor(string, bytes)
      string = Util.to_binary(string)
      string.bytes.zip(bytes).map { |a, b| a ^ b }.pack('C*')
    end

    def generate_default(gen, parameters)
      set = CharacterSet.new parameters.flags
      result = ''
      while result.length < parameters.length
        result += gen.call.select do |x|
          set.include?(x)
        end.pack('C*')
      end
      result[0, parameters.length]
    end

    def compute_checksum
      digest = OpenSSL::Digest::SHA256.new
      [@prefix, 'Quick Check: ', @master_secret].each do |s|
        s = Daniel::Util.to_binary(s)
        digest.update([s.bytesize].pack('N'))
        digest.update(s)
      end
      Daniel::Util.to_binary(digest.digest[0, 3])
    end

    def process_strings(strings, salt)
      str = Daniel::Util.to_binary('')
      strings.each do |s|
        s = Daniel::Util.to_binary(s)
        str += [s.bytesize].pack('N') + s
      end
      digest = OpenSSL::Digest::SHA256.new
      OpenSSL::PKCS5.pbkdf2_hmac(str, salt, 1024, 32, digest)
    end
  end

  # A base class for daniel-related command-line interface.
  class Program
    def initialize
      @stdin = $stdin unless @stdin
      @prompt = @stdin.isatty ? :interactive : :human unless @prompt
    end

    protected

    def prompt(text, machine, *args)
      Object.send :require, 'cgi'
      nl = !machine_readable? && machine[-1] == '?' ? '' : "\n"
      args.map! { |s| CGI.escape(s.to_s) } if machine_readable?
      argtext = args.join(' ')
      print(machine_readable? ? machine : text, ' ', argtext, nl)
    end

    # Is the output machine-readable?
    def machine_readable?
      @prompt == :machine
    end

    def interactive(*args)
      prompt(*args) unless @prompt == :human
    end

    def read_passphrase
      begin
        Object.send :require, 'io/console'
        pass = @stdin.noecho(&:gets).chomp
      rescue Errno::ENOTTY
        pass = @stdin.gets.chomp
      end
      Version.smart_implementation? ? pass.encode('UTF-8') : pass
    end
  end

  # The main command-line interface.
  class MainProgram < Program # rubocop:disable Metrics/ClassLength
    def initialize
      @config = Configuration.new
      @params = @config.parameters(:default)
      @clipboard = false
      @mode = :password
      @format = :plain
      super
    end

    def main(args)
      args = args.dup
      return unless parse_args(args)
      sanity_check
      return estimate if @mode == :estimate
      return parse(args) if @mode == :parse
      loop do
        catch(:restart) do
          main_loop(args)
          return
        end
      end
    end

    private

    def parse_args(args) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      Object.send :require, 'optparse'

      flags_set = false
      existing_set = false
      OptionParser.new do |opts|
        opts.banner = 'Usage: daniel [-mrep] [-f FLAGS] [-l LENGTH] [-v VER]'

        opts.on('-v PASSWORD-VERSION', 'Set version') do |version|
          @params.version = version
        end

        opts.on('--format-version FORMAT-VERSION', 'Set format version') do |v|
          @params.format_version = v
        end

        opts.on('-f FLAGS', 'Set flags') do |flags|
          @params.flags = flags
          flags_set = true
        end

        opts.on('-l LENGTH', 'Set length') do |length|
          @params.length = length
        end

        opts.on('-m', 'Generate reminders from existing passwords') do
          @params.flags = Flags::REPLICATE_EXISTING
          existing_set = true
        end

        opts.on('-r', 'Produce machine-readable output') do
          @prompt = :machine
        end

        opts.on('-e', 'Generate entropy estimates') do
          @mode = :estimate
        end

        opts.on('-p', 'Store passwords to clipboard') do
          @clipboard = true
        end

        opts.on('-a', 'Parse reminders from the command line') do
          @mode = :parse
        end

        opts.on('-P FORMAT', 'Output passwords in another form') do |format|
          unless %w(plain bubblebabble).include? format
            fail OptionParser::InvalidArgument, "not a valid format '#{format}'"
          end
          @format = format.to_sym
        end

        opts.on('-t PRESET', 'Default parameters to a preset value') do |preset|
          p = @config.parameters(preset)
          unless p
            fail OptionParser::InvalidArgument, "not a valid preset '#{preset}'"
          end
          @params = p
        end

        opts.on_tail('-h', '--help', 'Show this message') do
          puts opts
          puts 'Flags values:'
          Flags.flag_names.each_with_index do |name, i|
            puts format('    0x%02x: %s', 1 << i, name)
          end
          return false
        end
      end.parse!(args)

      if flags_set && existing_set
        fail OptionParser::InvalidArgument, "Can't use both -m and -f"
      end

      true
    end

    def sanity_check
      return unless @clipboard
      begin
        Object.send :require, 'clipboard'
      rescue LoadError
        @clipboard = false
        warn "Can't load clipboard gem; passwords will be printed"
      end
    end

    def handle_command(generator, code)
      # Strip off the leading !.
      name, value = code[1..-1].split(/=/)
      throw :restart if name =~ /\Apass(word|phrase)?\z/
      if name =~ /\Arem(inder)?\z/
        return generate_from_reminder(generator, value)
      end
      sym = "#{name}=".to_sym
      begin
        @params.method(sym).call(value)
      rescue NameError
        prompt "Not a valid command: '#{name}'", ':invalid-command!'
      end
    end

    def output_password(pass)
      if @clipboard
        Clipboard.copy pass
        puts 'Password copied to clipboard.'
      else
        prompt 'Password is:', ':password', pass
      end
    end

    def read_line
      @stdin.readline.chomp
    end

    def encode(pass, binary = false)
      encoded = Formatter.method(@format).call(pass)
      binary && @format == :plain ? humanify(encoded) : encoded
    end

    def estimate
      possibles = CharacterSet.new(@params.flags).length
      nchars = @params.length
      # Ruby 1.8 doesn't implement Math#log2 or Float#round with an argument.
      bits = (Math.log(possibles) / Math.log(2) * 1000).round / 1000.0
      tbits = bits * nchars
      if machine_readable?
        puts ":length #{nchars}\n:possible-char #{possibles}\n" \
          ":bits-per-char #{bits}\n:bits-total #{tbits}"
      else
        puts "#{nchars} characters; #{possibles} possible (#{bits} bpc); " \
          "#{tbits} bits of entropy"
      end
    end

    def humanify(text)
      text && !machine_readable? ? Util.to_hex(text) : text
    end

    def parse(args) # rubocop:disable Metrics/AbcSize
      args.each do |reminder|
        rem = Reminder.parse(reminder, :skip_verify => true)
        params = rem.params
        flags = Flags.explain(params.flags)
        mac = humanify(rem.mac)
        mask = humanify(rem.mask)
        salt = humanify(params.salt)
        prompt 'Reminder is:', ':reminder', reminder
        prompt 'Version:', ':version', params.format_version
        prompt 'Length:', ':length', params.length
        prompt 'Password version:', ':password-version', params.version
        prompt 'Flags:', ':flags', params.flags, *flags
        prompt 'Iterations:', ':iterations', params.iterations
        prompt 'Salt:', ':salt', salt if salt
        prompt 'Checksum:', ':checksum', rem.checksum
        prompt 'Mask:', ':mask', mask if mask
        prompt 'MAC:', ':mac', mac if mac
        prompt 'Code:', ':code', rem.code
      end
    end

    def query_existing
      interactive 'Enter existing passphrase:', ':existing?'
      current = read_passphrase
      if @prompt == :interactive
        print "\nRepeat existing passphrase: " if @stdin.isatty
        current2 = read_passphrase
        if current != current2
          puts "\nPassphrases did not match."
          return nil
        end
        print "\n"
      end
      current
    end

    def dispatch_by_code(generator, code)
      return handle_command(generator, code) if code[0, 1] == '!'
      if @params.existing_mode?
        current = query_existing
        return unless current
        @params.length = current.length
        mask = generator.generate_mask(code, @params, current)
      else
        output_password(encode(generator.generate(code, @params),
                               @params.binary?))
        mask = nil
      end
      prompt('Reminder is:', ':reminder',
             generator.reminder(code, @params, mask))
    end

    def generate_from_reminder(generator, reminder)
      rem = generator.parse_reminder(reminder)
      bin = rem.params.binary?
      output_password(encode(generator.generate_from_reminder(rem), bin))
    end

    def prompt_and_dispatch(generator)
      code = nil
      loop do
        interactive 'Enter code:', ':code?'
        lastcode = code
        code = read_line
        code = lastcode if code == '!!'
        dispatch_by_code(generator, code)
      end
    rescue EOFError
      return
    end

    def main_loop(args)
      prompt 'Please enter your master password:', ':master-password?'
      pass = read_passphrase
      print "\n"
      generator = PasswordGenerator.new pass, @params.format_version
      prompt '# ok, checksum is', ':checksum', Util.to_hex(generator.checksum)
      if args.empty?
        prompt_and_dispatch(generator)
      else
        args.each { |reminder| generate_from_reminder(generator, reminder) }
      end
    end
  end
end

Daniel::MainProgram.new.main(ARGV) if __FILE__ == $PROGRAM_NAME

#!/usr/bin/ruby
# daniel - a password generator
#
# Copyright © 2013–2014 brian m. carlson
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

Kernel.send :require, 'openssl'
require 'set'

# A password generation tool.
module Daniel
  # The class from which all Daniel exceptions derive.
  class Exception < ::Exception
  end

  # The version number of Daniel.
  class Version
    def self.to_s
      '0.1.0'
    end

    # Are we dealing with a reasonably modern and feature-complete
    # implementation?
    def self.smart_implementation?
      return ::RUBY_ENGINE != 'opal' && ::RUBY_VERSION.to_f > 1.8
    end
  end

  # Utility functions.
  class Util
    def self.to_hex(s)
      s.unpack('H*')[0]
    end

    def self.from_hex(s)
      result = [s].pack('H*')
      to_binary(result)
    end

    def self.to_binary(s)
      Version.smart_implementation? ? s.force_encoding('BINARY') : s
    end
  end

  # Flag constants and conversion functions.
  class Flags
    NO_NUMBERS = 0x01
    NO_SPACES = 0x02
    NO_SYMBOLS_TOP = 0x04
    NO_SYMBOLS_OTHER = 0x08
    NO_LETTERS = 0x10
    SYMBOL_MASK = 0x1f
    REPLICATE_EXISTING = 0x20
    IMPLEMENTED_MASK = 0x3f
    EXPLICIT_VERSION = 0x40

    # Compute a flag value from a number or string.
    #
    # @param text [String, Fixnum] the value to convert to a flags value
    # @returns [Fixnum] the computed value.
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
        value = SYMBOL_MASK
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
    # @returns [Array<String>] the list of strings representing the value
    def self.explain(value)
      flags = flag_names
      if value < 0 || value > ((1 << flags.length) - 1)
        fail Exception, 'Invalid flags value'
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
      pairs.map { |k, _| k.to_s.downcase.gsub('_', '-') }
    end
  end

  # A set of characters which are acceptable in a generated password.
  class CharacterSet < ::Set
    def initialize(options = Flags::NO_SPACES | Flags::NO_SYMBOLS_OTHER)
      super(0x20..0x7e)
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

    def self.from_characters(text)
      new Flags.mask_from_characters(text)
    end
  end

  # The parameters affecting generation of a password.
  class Parameters
    attr_reader :flags, :length, :version, :salt, :format_version

    def initialize(flags = 10, length = 16, version = 0, options = {})
      self.flags = flags
      @length = length
      @version = version
      self.salt = options[:salt]
      @format_version = options[:format_version] || 0
    end

    def flags=(flags)
      flags = Flags.mask_from_characters(flags)
      if (flags & ~Flags::IMPLEMENTED_MASK) != 0
        fail Exception, format('Not a valid flags value %08x', flags)
      end
      flags &= ~Flags::SYMBOL_MASK if (flags & Flags::REPLICATE_EXISTING) != 0
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

    def existing_mode?
      (@flags & Flags::REPLICATE_EXISTING) != 0
    end

    def ==(other)
      [:flags, :length, :version, :salt, :format_version].each do |m|
        return false unless method(m).call == other.method(m).call
      end
      true
    end

    alias_method :eql?, :==
  end

  # A parsed reminder value
  Reminder = Struct.new(:params, :checksum, :code, :mask) do
    # Parse a reminder into its constituent parts.
    #
    # @param rem [String] the complete reminder string
    # @return [Reminder] the parsed set of parameters
    def self.parse(rem)
      params = Parameters.new
      csum = rem[0..5]
      if rem[6..-1] =~ /^((?:(?:[89a-f][0-9a-f])*[0-9a-f][0-9a-f]){3})(.*)$/
        hex_params, code = Regexp.last_match[1..2]
        dparams = Util.from_hex(hex_params)
        flags, length, version = dparams.unpack('w3')
        if (flags & Flags::REPLICATE_EXISTING) != 0
          if code =~ /^([0-9a-f]{#{2 * length}})(.*)$/
            mask, code = Regexp.last_match[1..2]
            mask = Util.from_hex(mask)
          else
            fail Exception, 'Flags set to existing but mask missing'
          end
        else
          mask = nil
        end
      end
      params.flags = flags
      params.length = length
      params.version = version
      Reminder.new(params, csum, code, mask)
    end

    def to_s
      p = params
      bytes = checksum + [p.flags, p.length, p.version].pack('w3')
      bytes += mask if mask
      Util.to_hex(bytes) + code
    end
  end

  # Format a password or other text.
  class Formatter
    def self.plain(s)
      s
    end

    def self.bubblebabble(s)
      vo = %w(a e i o u y)
      co = %w(b c d f g h k l m n p r s t v z x)
      s = Util.to_binary(s)
      r = s.each_byte.to_a
      len = r.length / 2
      k = []
      (len + 1).times do |i|
        k[i] = i == 0 ? 1 : (((k[i - 1] * 5) +
                              (r[i * 2 - 2] * 7 + r[i * 2 - 1])) % 36)
      end
      t = []
      len.times do |i|
        t[i] = [
          (((r[i * 2] >> 6) & 3) + k[i]) % 6,
          (r[i * 2] >> 2) & 15,
          ((r[i * 2] & 3) + (k[i] / 6)) % 6,
          (r[i * 2 + 1] >> 4) & 15,
          (r[i * 2 + 1] & 15)
        ]
      end
      lastr = r.length - 1
      p = r.length.even? ?  [k[len] % 6, 16, k[len] / 6] :
        [(((r[lastr] >> 6) & 3) + k[len]) % 6,
         (r[lastr] >> 2) & 15,
         ((r[lastr] & 3) + k[len] / 6) % 6
        ]
      res = t.map do |(a, b, c, d, e)|
        [vo[a], co[b], vo[c], co[d], '-', co[e]].join('')
      end
      'x' + res.join('') + vo[p[0]] + co[p[1]] + vo[p[2]] + 'x'
    end
  end

  # Generates a password or set of passwords.
  class PasswordGenerator
    def initialize(pass, version = 0)
      @version = version
      @prefix = format('DrewPassChart: Version 0x%08x: ', version)
      @master_secret = process_strings([@prefix, 'Master Secret: ', pass], '')
      @checksum = nil
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
      fail Exception, 'Invalid flags' unless params.existing_mode?
      generate(code, params, password)
    end

    def generate(code, params, mask = nil)
      flags = format('Flags 0x%08x: ', params.flags)
      version = format('Version 0x%08x: ', params.version)

      cipher = OpenSSL::Cipher::AES.new(256, :CTR)
      cipher.encrypt
      cipher.key = @master_secret
      cipher.iv = process_strings([@prefix, 'IV: ', flags, version, code],
                                  @master_secret)

      return generate_existing(cipher, params, mask) if params.existing_mode?
      generate_default(cipher, params)
    end

    def generate_from_reminder(reminder)
      rem = Reminder.parse(reminder)
      computed = Util.to_hex(checksum)
      if rem.checksum != computed
        fail Exception, "Checksum mismatch (#{rem.checksum} != #{computed})"
      end

      generate(rem.code, rem.params, rem.mask)
    end

    def reminder(code, p, mask = nil)
      Reminder.new(p, checksum, code, mask).to_s
    end

    private

    def generate_existing(cipher, parameters, mask)
      fail Exception, 'Invalid mask length' if parameters.length != mask.length
      cipher.update(mask)
    end

    def generate_default(cipher, parameters)
      set = CharacterSet.new parameters.flags
      buffer = ([0] * 32).pack('C*')
      result = ''
      while result.length < parameters.length
        result += cipher.update(buffer).bytes.select do |x|
          set.include?(x)
        end.pack('C*')
      end
      result[0, parameters.length]
    end

    def compute_checksum
      digest = OpenSSL::Digest::SHA256.new
      [@prefix, 'Quick Check: ', @master_secret].each do |s|
        digest.update([s.bytesize].pack('N'))
        digest.update(s)
      end
      digest.digest[0, 3]
    end

    def process_strings(strings, salt)
      str = Daniel::Util.to_binary('')
      strings.each do |s|
        str += [s.bytesize].pack('N') + s
      end
      digest = OpenSSL::Digest::SHA256.new
      OpenSSL::PKCS5.pbkdf2_hmac(str, salt, 1024, 32, digest)
    end
  end

  # The main command-line interface.
  class MainProgram   # rubocop:disable Style/ClassLength
    def initialize
      @params = Parameters.new
      @clipboard = false
      @mode = :password
      @prompt = $stdin.isatty ? :interactive : :human unless @prompt
      @format = :plain
    end

    def main(args)
      args = args.dup
      parse_args(args)
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

    def parse_args(args)  # rubocop:disable Style/MethodLength
      Object.send :require, 'optparse'

      flags_set = false
      existing_set = false
      OptionParser.new do |opts|
        opts.banner = 'Usage: daniel [-mrep] [-f FLAGS] [-l LENGTH] [-v VER]'

        opts.on('-v PASSWORD-VERSION', 'Set version') do |version|
          @params.version = version
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
            fail Exception, "not a valid format '#{format}'"
          end
          @format = format.to_sym
        end
      end.parse!(args)
      fail Exception, "Can't use both -m and -f" if flags_set && existing_set
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

    def handle_command(code)
      # Strip off the leading !.
      name, value = code[1..-1].split(/=/)
      throw :restart if name =~ /\Apass(word|phrase)?\z/
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

    def read_passphrase
      begin
        Object.send :require, 'io/console'
        pass = STDIN.noecho(&:gets).chomp
      rescue Errno::ENOTTY
        pass = STDIN.gets.chomp
      end
      Version.smart_implementation? ? pass.encode('UTF-8') : pass
    end

    def read_line
      STDIN.readline.chomp
    end

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

    def encode(pass)
      Formatter.method(@format).call(pass)
    end

    def estimate
      cs = CharacterSet.new @params.flags & Flags::SYMBOL_MASK
      nchars = @params.length
      possibles = cs.length
      # Ruby 1.8 doesn't implement Math#log2 or Float#round with an argument.
      bits = (Math.log(possibles) / Math.log(2) * 1000).round / 1000.0
      if machine_readable?
        puts ":length #{nchars}\n:possible-char #{possibles}"
        puts ":bits-per-char #{bits}\n:bits-total #{nchars * bits}"
      else
        msg = "#{nchars} characters; #{possibles} possible (#{bits} bpc); "
        msg += "#{nchars * bits} bits of entropy"
        puts msg
      end
    end

    def humanify(text)
      text && !machine_readable? ? Util.to_hex(text) : text
    end

    def parse(args)
      args.each do |reminder|
        rem = Reminder.parse(reminder)
        params = rem.params
        flags = Flags.explain(params.flags)
        mask = humanify(rem.mask)
        salt = humanify(params.salt)
        prompt 'Reminder is:', ':reminder', reminder
        prompt 'Version:', ':version', params.format_version
        prompt 'Length:', ':length', params.length
        prompt 'Password version:', ':password-version', params.version
        prompt 'Flags:', ':flags', params.flags, *flags
        prompt 'Salt:', ':salt', salt if salt
        prompt 'Checksum:', ':checksum', rem.checksum
        prompt 'Mask:', ':mask', mask if mask
        prompt 'Code:', ':code', rem.code
      end
    end

    def query_existing
      interactive 'Enter existing passphrase:', ':existing?'
      current = read_passphrase
      if @prompt == :interactive
        print "\nRepeat existing passphrase: " if STDIN.isatty
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
      return handle_command(code) if code[0, 1] == '!'
      if @params.existing_mode?
        current = query_existing
        return unless current
        @params.length = current.length
        mask = generator.generate_mask(code, @params, current)
      else
        output_password(encode(generator.generate(code, @params)))
        mask = nil
      end
      prompt('Reminder is:', ':reminder',
             generator.reminder(code, @params, mask))
    end

    def main_loop(args)
      prompt 'Please enter your master password:', ':master-password?'
      pass = read_passphrase
      print "\n"
      generator = PasswordGenerator.new pass, 0
      prompt '# ok, checksum is', ':checksum', Util.to_hex(generator.checksum)
      if args.empty?
        begin
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
      else
        args.each do |reminder|
          output_password(encode(generator.generate_from_reminder(reminder)))
        end
      end
    end
  end
end

Daniel::MainProgram.new.main(ARGV) if __FILE__ == $PROGRAM_NAME

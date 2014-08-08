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

require 'English'
require 'cgi'
require 'openssl'
require 'optparse'
require 'set'

module Daniel
  class Util
    def self.to_hex(s)
      s.unpack('H*')[0]
    end

    def self.from_hex(s)
      result = [s].pack('H*')
      ::RUBY_VERSION.to_f <= 1.8 ? result : result.force_encoding('BINARY')
    end
  end

  class Flags
    NO_NUMBERS = 0x01
    NO_SPACES = 0x02
    NO_SYMBOLS_TOP = 0x04
    NO_SYMBOLS_OTHER = 0x08
    NO_LETTERS = 0x10
    SYMBOL_MASK = 0x1f
    REPLICATE_EXISTING = 0x20
    EXPLICIT_VERSION = 0x40

    def self.mask_from_characters(text)
      if text.is_a?(Fixnum)
        return text
      elsif text =~ /\A0[0-7]+\z/
        return text.to_i(8)
      elsif text =~ /\A\d+\z/
        return text.to_i
      elsif text =~ /\A0[xX][A-Fa-f0-9]+\z/
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
        masks.keys.each { |ch| value &= ~masks[ch] if text[ch] }
        return value
      end
    end
  end

  class CharacterSet < ::Set
    NO_NUMBERS = Flags::NO_NUMBERS
    NO_SPACES = Flags::NO_SPACES
    NO_SYMBOLS_TOP = Flags::NO_SYMBOLS_TOP
    NO_SYMBOLS_OTHER = Flags::NO_SYMBOLS_OTHER
    NO_LETTERS = Flags::NO_LETTERS
    SYMBOL_MASK = Flags::SYMBOL_MASK

    def initialize(options = NO_SPACES | NO_SYMBOLS_OTHER)
      super([])
      (0x20..0x7e).each { |x| add(x) }
      m = {
        NO_NUMBERS => 0x30..0x39,
        NO_SPACES => [0x20],
        NO_SYMBOLS_TOP => '!@#$%^&*()'.each_byte,
        NO_SYMBOLS_OTHER => '"\'+,-./:;<=>?[\\]_`{|}~'.each_byte,
        NO_LETTERS => [(0x41..0x5a).to_a, (0x61..0x7a).to_a].flatten
      }
      m.each do |k, v|
        v.each { |x| delete(x) } if options & k != 0
      end
    end

    def self.from_characters(text)
      new Flags.mask_from_characters(text)
    end
  end

  class Parameters
    attr_reader :flags, :length, :version

    def initialize(flags = 10, length = 16, version = 0)
      self.flags = flags
      @length = length
      @version = version
    end

    def flags=(flags)
      flags = Flags.mask_from_characters(flags)
      flags &= ~Flags::SYMBOL_MASK if (flags & Flags::REPLICATE_EXISTING) != 0
      @flags = flags
    end

    def length=(length)
      length = length.to_i
      @length = length
    end

    def version=(version)
      version = version.to_i
      @version = version
    end

    def existing_mode?
      (@flags & Flags::REPLICATE_EXISTING) != 0
    end

    def ==(other)
      [:flags, :length, :version].each do |m|
        return false unless method(m).call == other.method(m).call
      end
      true
    end

    alias_method :eql?, :==
  end

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

    # Because of the way XOR works, if the mask argument is the password, this
    # function will return the mask.
    def generate(code, parameters, mask = nil)
      flags = format('Flags 0x%08x: ', parameters.flags)
      version = format('Version 0x%08x: ', parameters.version)
      set = CharacterSet.new parameters.flags

      cipher = OpenSSL::Cipher::AES.new(256, :CTR)
      cipher.encrypt
      cipher.key = @master_secret
      cipher.iv = process_strings([@prefix, 'IV: ', flags, version, code],
                                  @master_secret)

      if parameters.existing_mode?
        fail 'Invalid mask length' if parameters.length != mask.length

        keystream = cipher.update(([0] * parameters.length).pack('C*'))
        pairs = keystream.each_byte.zip(mask.each_byte)
        pairs.map { |(x, y)| x ^ y }.pack('C*')
      else
        buffer = ([0] * 32).pack('C*')
        result = ''
        while result.length < parameters.length
          result << cipher.update(buffer).bytes.select do |x|
            set.include?(x)
          end.pack('C*')
        end
        result[0, parameters.length]
      end
    end

    # Parse a reminder into its constituent parts.
    #
    # @param reminder [String] the complete reminder string
    # @return [Hash] a hash containing a set of parameters (key :params),
    #   hex-encoded checksum (:checksum), code (:code), and mask (:mask)
    def self.parse_reminder(reminder)
      params = Parameters.new
      csum = reminder[0..5]
      if reminder[6..-1] =~ /\A((?:(?:[89a-f][0-9a-f])*[0-9a-f][0-9a-f]){3})
          (.*)\z/x
        hex_params, code = Regexp.last_match[1..2]
        dparams = Util.from_hex(hex_params)
        flags, length, version = dparams.unpack('w3')
        if (flags & Flags::REPLICATE_EXISTING) != 0 &&
          code =~ /\A([0-9a-f]{#{2 * length}})(.*)\z/
          mask, code = Regexp.last_match[1..2]
          mask = Util.from_hex(mask)
        else
          mask = nil
        end
      end
      params.flags = flags
      params.length = length
      params.version = version
      { :params => params, :checksum => csum, :code => code, :mask => mask,
        :reminder => reminder }
    end

    def generate_from_reminder(reminder)
      pieces = self.class.parse_reminder(reminder)
      computed = Util.to_hex(checksum)
      if pieces[:checksum] != computed
        fail "Checksum mismatch (#{pieces[:checksum]} != #{computed})"
      end

      generate(pieces[:code], pieces[:params], pieces[:mask])
    end

    def reminder(code, p, mask = nil)
      bytes = checksum + [p.flags, p.length, p.version].pack('w3')
      bytes << mask if mask
      Util.to_hex(bytes) + code
    end

    private

    def compute_checksum
      digest = OpenSSL::Digest::SHA256.new
      [@prefix, 'Quick Check: ', @master_secret].each do |s|
        digest.update([s.bytesize].pack('N'))
        digest.update(s)
      end
      digest.digest[0, 3]
    end

    def process_strings(strings, salt)
      str = ''
      strings.each do |s|
        str << [s.bytesize].pack('N') << s
      end
      digest = OpenSSL::Digest::SHA256.new
      OpenSSL::PKCS5.pbkdf2_hmac(str, salt, 1024, 32, digest)
    end
  end

  class MainProgram
    def initialize
      @params = Parameters.new
      @clipboard = false
      @mode = :password
      @prompt = $stdin.isatty ? :interactive : :human unless @prompt
    end

    def parse_args(args)
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
      end.parse!(args)
      fail "Can't use both -m and -f" if flags_set && existing_set
    end

    def sanity_check
      return unless @clipboard
      begin
        require 'clipboard'
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
      @params.method(sym).call(value)
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
        require 'io/console'
        pass = STDIN.noecho(&:gets).chomp
      rescue Errno::ENOTTY
        pass = STDIN.gets.chomp
      end
      ::RUBY_VERSION.to_f <= 1.8 ? pass : pass.encode('UTF-8')
    end

    def read_line
      STDIN.readline.chomp
    end

    def prompt(text, machine, *args)
      nl = !machine_readable? && machine[-1] == '?' ? '' : "\n"
      args.map! { |s| CGI.escape(s) } if machine_readable?
      # This weirdness is required because Ruby 1.8 doesn't allow the splat in
      # the middle of a function call.
      args = [machine_readable? ? machine : text, ' '] + args + [nl]
      print(*args)
    end

    # Is the output machine-readable?
    def machine_readable?
      @prompt == :machine
    end

    def interactive(*args)
      return if @prompt == :human
      prompt(*args)
    end

    def estimate
      cs = CharacterSet.new @params.flags & Flags::SYMBOL_MASK
      nchars = @params.length
      possibles = cs.length
      bits = Math.log2(possibles).round(3)
      if machine_readable?
        puts ":char #{nchars}\n:possible-char #{possibles}"
        puts ":bits-per-char #{bits}\n:bits-total #{nchars * bits}"
      else
        msg = "#{nchars} characters; "
        msg << "#{possibles} possible (#{bits} bpc); "
        msg << "#{nchars * bits} bits of entropy"
        puts msg
      end
    end

    def main(args)
      args = args.dup
      parse_args(args)
      sanity_check
      return estimate if @mode == :estimate
      loop do
        catch(:restart) do
          main_loop(args)
          return
        end
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
      if code[0, 1] == '!'
        handle_command(code)
      else
        if @params.existing_mode?
          current = query_existing
          return unless current
          @params.length = current.length
          mask = generator.generate(code, @params, current)
        else
          output_password(generator.generate(code, @params))
          mask = nil
        end
        prompt('Reminder is:', ':reminder',
               generator.reminder(code, @params, mask))
      end
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
          output_password(generator.generate_from_reminder(reminder))
        end
      end
    end
  end
end

Daniel::MainProgram.new.main(ARGV) if __FILE__ == $PROGRAM_NAME

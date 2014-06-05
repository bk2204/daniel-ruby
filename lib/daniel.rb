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
        masks.keys.each do |ch|
          if text[ch]
            value &= ~masks[ch]
          end
        end
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
      (0x20..0x7e).each do |x|
        add(x)
      end
      if options & NO_NUMBERS != 0
        (0x30..0x39).each do |x|
          delete(x)
        end
      end
      if options & NO_SPACES != 0
        delete(0x20)
      end
      if options & NO_SYMBOLS_TOP != 0
        '!@#$%^&*()'.each_byte do |x|
          delete(x)
        end
      end
      if options & NO_SYMBOLS_OTHER != 0
        '"\'+,-./:;<=>?[\\]_`{|}~'.each_byte do |x|
          delete(x)
        end
      end
      if options & NO_LETTERS != 0
        (0x41..0x5a).each do |x|
          delete(x)
        end
        (0x61..0x7a).each do |x|
          delete(x)
        end
      end
    end

    def self.from_characters(text)
      return self.new Flags.mask_from_characters(text)
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
  end

  class PasswordGenerator
    def initialize(pass, version = 0)
      @version = version
      @prefix = 'DrewPassChart: Version 0x%08x: ' % version
      @master_secret = process_strings([@prefix, 'Master Secret: ', pass], '')
      @checksum = nil
    end

    def checksum
      return @checksum if !@checksum.nil?
      @checksum = compute_checksum
    end

    # Because of the way XOR works, if the mask argument is the password, this
    # function will return the mask.
    def generate(code, parameters, mask = nil)
      flags = 'Flags 0x%08x: ' % parameters.flags
      version = 'Version 0x%08x: ' % parameters.version
      set = CharacterSet.new parameters.flags

      cipher = OpenSSL::Cipher::AES.new(256, :CTR)
      cipher.encrypt
      cipher.key = @master_secret
      cipher.iv = process_strings([@prefix, 'IV: ', flags, version, code],
                    @master_secret)

      if (parameters.flags & Flags::REPLICATE_EXISTING) != 0
        raise 'Invalid mask length' if parameters.length != mask.length

        keystream = cipher.update(([0] * parameters.length).pack('C*'))
        pairs = keystream.each_byte.zip(mask.each_byte)
        result = pairs.map { |(x, y)| x ^ y }.pack('C*')
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
      return {:params => params, :checksum => csum, :code => code,
              :mask => mask}
    end

    def generate_from_reminder(reminder)
      pieces = self.class.parse_reminder(reminder)
      computed = Util.to_hex(checksum)
      if pieces[:checksum] != computed
        raise "Checksum mismatch (#{pieces[:checksum]} != #{computed})"
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
    def parse_args(args)
      @params = Parameters.new
      @clipboard = false
      flags_set = false
      existing_set = false
      OptionParser.new do |opts|
        opts.banner = 'Usage: daniel [-flvm]'

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

        opts.on('-p', 'Store passwords to clipboard') do
          begin
            require 'clipboard'
            @clipboard = true
          rescue LoadError
            warn "Can't load clipboard gem; passwords will be printed"
          end
        end
      end.parse!(args)
      if flags_set && existing_set
        raise "Can't use both -m and -f"
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
        puts "Password is: #{pass}"
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

    def main(args)
      parse_args(args)
      loop do
        catch(:restart) do
          main_loop(args)
          return
        end
      end
    end

    def main_loop(args)
      print 'Please enter your master password: '
      pass = read_passphrase
      print "\n"
      generator = PasswordGenerator.new pass, 0
      puts "# ok, checksum is #{Util.to_hex(generator.checksum)}"
      if args.empty?
        begin
          code = nil
          loop do
            print 'Enter code: ' if STDIN.isatty
            lastcode = code
            code = read_line
            if code == '!!'
              code = lastcode
            end
            if code[0, 1] == '!'
              handle_command(code)
            else
              if (@params.flags & Flags::REPLICATE_EXISTING) != 0
                print 'Enter existing passphrase: ' if STDIN.isatty
                current = read_passphrase
                print "\nRepeat existing passphrase: " if STDIN.isatty
                current2 = read_passphrase
                if current != current2
                  puts "\nPassphrases did not match."
                  next
                end
                print "\n"
                @params.length = current.length
                mask = generator.generate(code, @params, current)
              else
                output_password(generator.generate(code, @params))
                mask = nil
              end
              puts "Reminder is: #{generator.reminder(code, @params, mask)}"
            end
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

if __FILE__ == $0
  Daniel::MainProgram.new.main(ARGV)
end

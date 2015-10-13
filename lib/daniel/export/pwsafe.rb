require 'daniel'
require 'daniel/bytegen'
require 'openssl'
require 'securerandom'
require 'twofish'

# A password generation tool.
module Daniel
  # Export to various formats.
  module Export
    # Export to PasswordSafe v3 format.
    class PasswordSafe
      FIELD_VERSION = 0
      FIELD_UUID = 0x01
      FIELD_TITLE = 0x03
      FIELD_PASS = 0x06
      FIELD_EOE = 0xff
      LATEST_VERSION = "\x0d\x03".freeze

      def initialize(pass, writer, options = {})
        tempsalt = options[:salt] || SecureRandom.random_bytes(32)
        @bgen = ByteGenerator.new(pass, tempsalt)
        @writer = writer
        salt, datakey, mackey, iv = 4.times.map { @bgen.random_bytes(32) }
        iv = iv[0..15]
        @encrypter = Twofish.new(datakey, :mode => :cbc, :padding => :none,
                                          :iv => iv)
        @mac = OpenSSL::HMAC.new(mackey, OpenSSL::Digest::SHA256.new)
        write_header(pass, salt, 4096, datakey + mackey, iv)
      end

      def add_entry(generator, reminder)
        rem = Reminder.parse(reminder)
        pass = generator.generate_from_reminder(rem)
        uuid = Util.from_hex(@bgen.uuid.gsub('-', ''))
        write_field(FIELD_UUID, uuid)
        write_field(FIELD_TITLE, rem.code)
        write_field(FIELD_PASS, pass)
        write_field(FIELD_EOE)
      end

      def finish
        @writer.print('PWS3-EOF' * 2)
        @writer.print(@mac.digest)
      end

      protected

      def write_header(pass, salt, iters, keyblock, iv)
        key = stretch(pass, salt, iters)
        @writer.print('PWS3')
        @writer.print(salt)
        @writer.print([iters].pack('V'))
        @writer.print(OpenSSL::Digest::SHA256.new.digest(key))
        tf = Twofish.new(key, :mode => :ecb, :padding => :none)
        @writer.print(tf.encrypt(keyblock))
        @writer.print(iv)
        write_database_header
      end

      # Write one or more full 128-bit (16-byte) blocks, encrypted and MAC'd.
      def write_encrypted(data)
        @writer.print(@encrypter.encrypt(data))
      end

      def write_field(type, data = '')
        unpadded = [data.bytesize, type].pack('VC') + data
        rem = unpadded.bytesize & 15
        # For some bizarre reason, we don't MAC the type or the length, or the
        # pad data.  But whatever.
        @mac << data
        p = rem == 0 ? unpadded : unpadded + @bgen.random_bytes(16 - rem)
        write_encrypted(p)
      end

      def write_database_header
        write_field(FIELD_VERSION, LATEST_VERSION)
        write_field(FIELD_EOE)
      end

      def stretch(pass, salt, iters)
        x0 = OpenSSL::Digest::SHA256.new.digest(Util.to_binary(pass) + salt)
        x = x0
        iters.times do
          x = OpenSSL::Digest::SHA256.new.digest(x)
        end
        x
      end
    end
  end
end

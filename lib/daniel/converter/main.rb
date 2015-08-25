require 'daniel/converter'

# A password generation tool.
module Daniel
  # Converts passwords from one master password to another.
  class Converter
    # Main program for daniel-convert.
    class MainProgram
      def main(args)
        oldpass, newpass = do_prompt
        converter = Daniel::Converter.new(oldpass, newpass)
        oldfile = File.new(args[0], 'r')
        newfile = File.new(args[1], 'w')
        oldfile.each_line do |l|
          if /^(#|\s*$)/.match(l)
            newfile.print(l)
          else
            newfile.puts(converter.convert(l.chomp))
          end
        end
      end

      protected

      def do_prompt
        print "Enter old passphrase: "
        old = read_passphrase
        generator = PasswordGenerator.new old
        puts "\n# ok, checksum is #{Daniel::Util.to_hex(generator.checksum)}"
        print "Enter new passphrase: "
        new = read_passphrase
        generator = PasswordGenerator.new new
        puts "\n# ok, checksum is #{Daniel::Util.to_hex(generator.checksum)}"
        [old, new]
      end

      def read_passphrase
        begin
          require 'io/console'
          pass = STDIN.noecho(&:gets).chomp
        rescue Errno::ENOTTY
          pass = STDIN.gets.chomp
        end
        Daniel::Version.smart_implementation? ? pass.encode('UTF-8') : pass
      end

      def read_line
        STDIN.readline.chomp
      end
    end
  end
end

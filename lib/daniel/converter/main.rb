require 'daniel/converter'

# A password generation tool.
module Daniel
  # Converts passwords from one master password to another.
  class Converter
    # Main program for daniel-convert.
    class MainProgram < Daniel::Program
      def main(args)
        oldpass, newpass = do_prompt
        converter = Daniel::Converter.new(oldpass, newpass)
        oldfile = File.new(args[0], 'r')
        newfile = File.new(args[1], 'w')
        oldfile.each_line do |l|
          newfile.puts(process_line(converter, l))
        end
      end

      protected

      def process_line(converter, line)
        if /^(#|\s*$)/ =~ line
          l
        else
          converter.convert(line.chomp)
        end
      end

      def do_prompt
        res = []
        # Use full phrases to allow for future translation
        [
          ['Enter old passphrase: ', ':master-password?'],
          ['Enter new passphrase: ', ':new-master-password?']
        ].each do |msg|
          interactive(*msg)
          pass = read_passphrase
          generator = PasswordGenerator.new pass
          puts "\n# ok, checksum is #{Daniel::Util.to_hex(generator.checksum)}"
          res << pass
        end
        res
      end

      def read_line
        STDIN.readline.chomp
      end
    end
  end
end

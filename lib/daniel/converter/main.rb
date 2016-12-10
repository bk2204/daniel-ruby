require 'optparse'
require 'daniel/converter'

# A password generation tool.
module Daniel
  # Converts passwords from one master password to another.
  class Converter
    # Main program for daniel-convert.
    class MainProgram < Daniel::Program
      def main(args)
        options, args = parse_options(args)
        return if options[:help]
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

      def parse_options(args)
        options = {}
        OptionParser.new do |opts|
          opts.banner = 'Usage: daniel-converter [-r] OLDFILE NEWFILE'

          opts.on_tail('-h', '--help', 'Show this message') do
            puts opts
            puts <<-EOM.gsub(/^\s+/, '')
            Read the entries from OLDFILE using one passphrase and rewrite them
            into NEWFILE using a different passphrase.
            EOM
            options[:help] = true
          end
        end.parse!(args)
        [options, args]
      end
    end
  end
end

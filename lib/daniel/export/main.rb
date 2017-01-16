require 'daniel/export/pwsafe'
require 'optparse'

# A password generation tool.
module Daniel
  # Export to various formats.
  module Export
    # Main program for daniel-export.
    class MainProgram < Daniel::Program
      def main(args)
        options, args = parse_options(args)
        return if options[:help]
        pass, generator = do_prompt
        srcfile = File.new(args[0], 'r')
        converter = Daniel::Export::PasswordSafe.new pass,
                                                     File.new(args[1], 'w')
        srcfile.each_line do |l|
          converter.add_entry(generator, l.chomp) unless /^(#|\s*$)/ =~ l
        end
      end

      protected

      def parse_options(args)
        options = {}
        OptionParser.new do |opts|
          opts.banner = 'Usage: daniel-export [-r] REMINDERS EXPORT'

          opts.on('-r', 'Produce machine-readable output') do
            @prompt = :machine
          end

          opts.on_tail('-h', '--help', 'Show this message') do
            puts opts
            puts <<-EOM.gsub(/^\s+/, '')
            Read reminders line by line from REMINDERS and produce a Password
            Safe v3 file in EXPORT.
            EOM
            options[:help] = true
          end
        end.parse!(args)
        [options, args]
      end

      def do_prompt
        interactive('Enter passphrase: ', ':master-password?')
        pass = read_passphrase
        generator = PasswordGenerator.new pass
        prompt '# ok, checksum is', ':checksum', Util.to_hex(generator.checksum)
        [pass, generator]
      end

      def read_line
        STDIN.readline.chomp
      end
    end
  end
end

require 'daniel/export/pwsafe'

# A password generation tool.
module Daniel
  # Export to various formats.
  module Export
    # Main program for daniel-convert.
    class MainProgram < Daniel::Program
      def main(args)
        pass, generator = do_prompt
        srcfile = File.new(args[0], 'r')
        destfile = File.new(args[1], 'w')
        converter = Daniel::Export::PasswordSafe.new(pass, destfile)
        srcfile.each_line do |l|
          converter.add_entry(generator, l.chomp) unless /^(#|\s*$)/.match(l)
        end
      end

      protected

      def do_prompt
        interactive('Enter passphrase: ', ':master-password?')
        pass = read_passphrase
        generator = PasswordGenerator.new pass
        puts "\n# ok, checksum is #{Daniel::Util.to_hex(generator.checksum)}"
        [pass, generator]
      end

      def read_line
        STDIN.readline.chomp
      end
    end
  end
end

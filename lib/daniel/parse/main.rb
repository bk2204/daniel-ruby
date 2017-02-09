require 'optparse'
require 'daniel'

# A password generation tool.
module Daniel
  # Parses reminders for a given master password.
  module Parse
    # Main program for daniel-parse.
    class MainProgram < Daniel::Program
      def main(args)
        options, args = parse_options(args)
        return if options[:help]
        gen = options[:prompt] && do_prompt
        pattern = Regexp.new(args[0])
        file = File.new(args[1], 'r')
        file.each_line do |l|
          result = process_line(gen, pattern, l.chomp)
          prompt 'Entry:', ':entry', *result if result
        end
      end

      protected

      def process_line(gen, pattern, line)
        return if /^(#|\s*$)/ =~ line
        begin
          rem = if gen
                  gen.parse_reminder(line)
                else
                  Reminder.parse(line, :skip_verify => true)
                end
          rem.code =~ pattern ? [rem.code, line] : nil
        rescue ChecksumMismatchError, JWTValidationError
          nil
        end
      end

      def do_prompt
        interactive('Enter passphrase: ', ':master-password?')
        pass = read_passphrase
        generator = PasswordGenerator.new pass
        puts "\n# ok, checksum is #{Daniel::Util.to_hex(generator.checksum)}"
        generator
      end

      def read_line
        STDIN.readline.chomp
      end

      def parse_options(args)
        options = {}
        OptionParser.new do |opts|
          opts.banner = 'Usage: daniel-parse [--prompt] [-r] PATTERN FILE'

          opts.on('--prompt', 'Prompt for a passphrase') do
            options[:prompt] = true
          end

          opts.on('-r', 'Machine readable') do
            @prompt = :machine
          end

          opts.on_tail('-h', '--help', 'Show this message') do
            puts opts
            puts <<-EOM.gsub(/^\s+/, '')
            Read the reminders from FILE with codes matching the regexp in
            PATTERN and print them to stdout.  If --prompt is used, prompts for
            a passphrase first; only reminders matching that passphrase are
            used.
            EOM
            options[:help] = true
          end
        end.parse!(args)
        [options, args]
      end
    end
  end
end

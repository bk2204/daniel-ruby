require 'daniel'

module Daniel
  module ThrowawayPass
    # Exceptions for this module.
    class Exception < Daniel::Exception
    end

    # Missing command-line argument.
    class MissingArgumentError < Exception
    end

    # Missing command-line argument.
    class MissingDataError < Exception
    end

    # Main program.
    class MainProgram < Daniel::Program
      def initialize
        initialize_variables
        fail MissingDataError, 'No passphrase provided' unless passphrase
        fail MissingDataError, 'No parameters provided' unless params
        super
      end

      def main(args)
        codes = parse_args(args.dup)
        passes = codes.map do |code|
          generator = PasswordGenerator.new passphrase
          generator.generate(code, params)
        end
        output_passwords(passes)
      end

      protected

      def initialize_variables
        @config = Configuration.new
        @clipboard = true
        @io = $stdout
      end

      def params
        return @params if @params
        @params = @config.parameters(:throwaway)
      end

      def passphrase
        @config.passphrase(:throwaway)
      end

      def parse_args(args)
        OptionParser.new do |opts|
          opts.banner = 'Usage: daniel-pass [-p] CODE...'

          opts.on('-p', 'Print passwords to standard output') do
            @clipboard = false
          end

          opts.on('-r', 'Use machine-readable output') do
            require 'cgi'
            @machine_readable = true
          end

          opts.on('-v VERSION', 'Set the password version') do |ver|
            params.version = ver
          end
        end.parse!(args)
        fail MissingArgumentError, 'No code provided' if args.empty?
        args.map(&:dup)
      end

      def output_passwords(passes)
        if @clipboard
          require 'clipboard'
          Clipboard.copy passes[0]
          @io.puts 'Password copied to clipboard.'
        else
          r = passes.map { |pass| @machine_readable ? CGI.escape(pass) : pass }
          @io.print r.join("\n")
        end
      end
    end
  end
end

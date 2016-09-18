require 'daniel'

module Daniel
  module ThrowawayPass
    # Exceptions for this module.
    class Exception < Daniel::Exception
    end

    # Missing command-line argument.
    class MissingArgumentError < Daniel::ThrowawayPass::Exception
    end

    # Missing command-line argument.
    class MissingDataError < Daniel::ThrowawayPass::Exception
    end

    # Main program.
    class MainProgram < Daniel::Program
      def initialize
        initialize_variables
        raise MissingDataError, 'No passphrase provided' unless passphrase
        raise MissingDataError, 'No parameters provided' unless params
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
        raise MissingArgumentError, 'No code provided' if args.empty?
        args.map(&:dup)
      end

      def output_passwords(passes)
        passes = passes.map { |p| @machine_readable ? CGI.escape(p) : p }
        if @clipboard
          require 'clipboard'
          Clipboard.copy passes[0]
          @io.puts 'Password copied to clipboard.'
        else
          @io.print passes.join("\n")
        end
      end
    end
  end
end

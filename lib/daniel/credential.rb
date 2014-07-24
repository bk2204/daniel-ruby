require 'daniel'
require 'open-uri'
require 'uri'

module Daniel
  # A set of classes providing automatic credential generation based on a set of
  # parameters.
  module CredentialHelper
    # The default implementation of a credential helper.
    #
    # This class provides support for reading a file or URL (supported by
    # open-uri) containing a list of valid reminder codes, one on each line, and
    # finding the first one that matches the master password's checksum which
    # has a code of the form user@*.domain or *.domain.
    #
    # This is designed to be subclassed to provide useful behavior more
    # appropriate to the user's situation, although this implementation may be
    # useful to some.
    class Base
      attr_writer :reminders
      attr_writer :master_password

      def initialize(resource = nil)
        @resource = resource
        url = 'https://github.com/bk2204/daniel-ruby'
        @user_agent = "daniel (+#{url}) Ruby/#{RUBY_VERSION}"
      end

      def reminders
        return @reminders if @reminders

        @reminders = []
        if @resource.respond_to? :each_line
          @reminders = read_resource(@resource)
        else
          open(@resource, 'User-Agent' => @user_agent) do |f|
            @reminders = read_resource(f)
          end
        end
        @reminders
      end

      def generate(params)
        acquire unless @master_password
        pgen = Daniel::PasswordGenerator.new(@master_password)
        selected = select(pgen.checksum, params)
        pgen.generate(selected[:code], selected[:params], selected[:mask])
      end

      protected

      def read_resource(io)
        reminders = []
        io.each_line do |line|
          next if line =~ /^\s*(?:#.*)?$/
          reminders << Daniel::PasswordGenerator.parse_reminder(line.strip)
        end
        reminders
      end

      def acquire
        fail 'No master password set!' unless @master_password
      end

      def selected(csum, params)
        fail 'No matching reminder!' unless reminders
        user, domain = params[:user], params[:domain]
        userpat = user ? /(?:(#{Regexp.escape(user)})@)?/ : /()/
        pat = /\A#{userpat}((?:.*\.)?#{Regexp.escape(domain)})\z/
        s = reminders.map do |r|
          if r[:checksum] == csum && r[:code] =~ pat
            [Regexp.last_match[1..2], r].flatten
          else
            nil
          end
        end
        result = s.select { |r| r }.sort do |a, b|
          cmp = b[0].to_s <=> a[0].to_s
          cmp.zero? ? a[1].length <=> b[1].length : cmp
        end.first
        fail 'No matching reminder!' unless result
        result[2]
      end
    end
  end
end

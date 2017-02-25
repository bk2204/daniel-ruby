#!/usr/bin/ruby
# encoding: UTF-8

require 'spec_helper'

if RUBY_ENGINE != 'opal'
  require 'daniel/export/main'

  module Daniel
    module Export
      # The main program class, but slightly more open.
      class MainProgram
        attr_accessor :passphrase

        def read_passphrase
          @passphrase
        end

        def prompt(*); end

        def interactive(*); end
      end
    end
  end

  describe Daniel::Export::MainProgram do
    it 'should produce a PasswordSafe v3 file' do
      Dir.mktmpdir do |dir|
        infile = File.join(dir, 'input')
        outfile = File.join(dir, 'output')

        f = File.new(infile, 'w')
        f.puts '72eb36021000example.tld'
        f.close

        prog = Daniel::Export::MainProgram.new
        prog.passphrase = 'foobar'
        prog.main([infile, outfile])

        output = File.read(outfile)
        expect(output).to start_with 'PWS3'
      end
    end
  end
end

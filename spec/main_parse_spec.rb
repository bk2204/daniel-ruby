#!/usr/bin/ruby
# encoding: UTF-8

require 'spec_helper'

if RUBY_ENGINE != 'opal'
  require 'stringio'
  require 'daniel/parse/main'

  module Daniel
    module Parse
      # The main program class, but slightly more open.
      class MainProgram
        attr_accessor :passphrase, :messages

        def read_passphrase
          @passphrase
        end

        def print(*args)
          @messages ||= []
          @messages << args.join
        end

        def interactive(*)
        end
      end
    end
  end

  describe Daniel::Parse::MainProgram do
    it 'should find matching entries' do
      Dir.mktmpdir do |dir|
        infile = File.join(dir, 'input')

        f = File.new(infile, 'w')
        f.puts '72eb36021000example.tld'
        f.puts '72eb36021000example.com'
        f.puts '72eb36021000nonexistent.example.tld'
        f.close

        prog = Daniel::Parse::MainProgram.new
        prog.main(['-r', 'example.tld', infile])

        expect(prog.messages).to eq [
          ":entry example.tld 72eb36021000example.tld\n",
          ":entry nonexistent.example.tld 72eb36021000nonexistent.example.tld\n"
        ]
      end
    end
  end
end

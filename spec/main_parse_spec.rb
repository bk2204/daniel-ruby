#!/usr/bin/ruby
# encoding: UTF-8

require 'spec_helper'

if RUBY_ENGINE != 'opal'
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
        prog.main(['example.tld', infile])

        expect(prog.messages).to eq [
          "Entry: example.tld 72eb36021000example.tld\n",
          "Entry: nonexistent.example.tld 72eb36021000nonexistent.example.tld\n"
        ]

        prog = Daniel::Parse::MainProgram.new
        prog.main(['-r', 'example.tld', infile])

        expect(prog.messages).to eq [
          ":entry example.tld 72eb36021000example.tld\n",
          ":entry nonexistent.example.tld 72eb36021000nonexistent.example.tld\n"
        ]
      end
    end

    it 'should find matching anonymous entries' do
      Dir.mktmpdir do |dir|
        infile = File.join(dir, 'input')

        anon_yes = '00000042018150eyJhbGciOiJIUzI1NiIsImtpZCI6IjE6MTk0MzU5OjA' \
          'wMDAwMDoyd0pfUDgwV2tZME1ZdmpjOExjWEpBIiwidHlwIjoiSldUIn0.eyJjb2RlI' \
          'joiZXhhbXBsZS50bGQiLCJmbGciOjY2LCJsZW4iOjE2LCJ2ZXIiOjB9.40slH9d8RM' \
          '1H8yEITr6ObutJn7d7LA8x_mnObg6YKVI'
        anon_no = '00000042018150eyJhbGciOiJIUzI1NiIsImtpZCI6IjE6MTk0MzU5OjAw' \
          'MDAwMDpNR3lNSzM0RHNpb28wNHltSkFyYjh3IiwidHlwIjoiSldUIn0.eyJjb2RlIj' \
          'oiZXhhbXBsZS5jb20iLCJmbGciOjY2LCJsZW4iOjE2LCJ2ZXIiOjB9.N-ZvoFJsBuK' \
          'p0kfQLiYwrTGNirybU0XqDTuY8H9cTDo'

        f = File.new(infile, 'w')
        f.puts '72eb36021000example.tld'
        f.puts '72eb36021000example.com'
        f.puts '72eb36021000nonexistent.example.tld'
        f.puts anon_yes
        f.puts anon_no
        f.close

        prog = Daniel::Parse::MainProgram.new
        prog.main(['example.tld', infile])

        expect(prog.messages).to eq [
          "Entry: example.tld 72eb36021000example.tld\n",
          "Entry: nonexistent.example.tld 72eb36021000nonexistent.example.tld\n",
          "Entry: example.tld #{anon_yes}\n"
        ]

        prog = Daniel::Parse::MainProgram.new
        prog.main(['-r', 'example.tld', infile])

        expect(prog.messages).to eq [
          ":entry example.tld 72eb36021000example.tld\n",
          ":entry nonexistent.example.tld 72eb36021000nonexistent.example.tld\n",
          ":entry example.tld #{anon_yes}\n"
        ]
      end
    end
  end
end

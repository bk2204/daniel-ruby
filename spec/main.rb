#!/usr/bin/ruby
# encoding: UTF-8

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'


module Daniel
  class MainProgram
    attr_accessor :passphrase, :passwords, :lines, :output

    def read_passphrase
      @passphrase
    end

    def output_password(pass, clipboard=false)
      @passwords ||= []
      @passwords << pass
    end

    def read_line
      if @lines.empty?
        raise EOFError
      end
      @lines.shift
    end

    def puts(*args)
      @output ||= []
      @output << args
    end

    def print(*args)
    end
  end
end

describe Daniel::MainProgram do
  it "parses args correctly" do
    prog = Daniel::MainProgram.new
    argdata = prog.parse_args(%w(-l8 -v1 -f15))
    argdata[:params].length.should eq 8
    argdata[:params].version.should eq 1
    argdata[:params].flags.should eq 15
  end

  it "generates reasonable output" do
    prog = Daniel::MainProgram.new
    prog.lines = ["example.tld"]
    prog.passphrase = "foobar"
    prog.main([])
    prog.passwords.should eq ["nj&xzO@hz&QvuoGY"]
    prog.output.flatten.should eq [
      "# ok, checksum is 72eb36",
      "Reminder is: 72eb360a1000example.tld"
    ]
  end
end

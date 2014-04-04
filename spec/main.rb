#!/usr/bin/ruby
# encoding: UTF-8

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'


module Daniel
  class MainProgram
    attr_accessor :passphrase, :passwords, :lines, :output, :warnings
    attr_accessor :params, :clipboard

    def read_passphrase
      @passphrase
    end

    def output_password(pass, clipboard=false)
      @passwords ||= []
      @passwords << pass
    end

    def warn(*args)
      @warnings ||= []
      @warnings << args
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
    prog.parse_args(%w(-l8 -v1 -f15))
    prog.params.length.should eq 8
    prog.params.version.should eq 1
    prog.params.flags.should eq 15
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

  it "processes commands properly" do
    prog = Daniel::MainProgram.new
    prog.lines = [
      "!length=8",
      "!version=1",
      "!flags=15",
      "example.tld"
    ]
    prog.passphrase = "foobar"
    prog.main([])
    prog.passwords.should eq ["mJRUHjid"]
    prog.output.flatten.should eq [
      "# ok, checksum is 72eb36",
      "Reminder is: 72eb360f0801example.tld"
    ]
  end

  it "processes command-line arguments properly" do
    prog = Daniel::MainProgram.new
    prog.lines = ["example.tld"]
    prog.passphrase = "foobar"
    prog.main(['-l8', '-v1', '-f15'])
    prog.passwords.should eq ["mJRUHjid"]
    prog.output.flatten.should eq [
      "# ok, checksum is 72eb36",
      "Reminder is: 72eb360f0801example.tld"
    ]
  end


  it "handles loading the clipboard gem properly" do
    prog = Daniel::MainProgram.new
    prog.lines = ["example.tld"]
    prog.passphrase = "foobar"
    prog.main(['-p'])
    if prog.clipboard
      # Check for absence of exception.
      Object.const_get('Clipboard')
    else
      prog.warnings.flatten.should eq [
        "Can't load clipboard gem; passwords will be printed"
      ]
    end
  end
end

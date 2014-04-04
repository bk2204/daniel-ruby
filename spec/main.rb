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
    expect(prog.params.length).to eq 8
    expect(prog.params.version).to eq 1
    expect(prog.params.flags).to eq 15
  end

  it "generates reasonable output" do
    prog = Daniel::MainProgram.new
    prog.lines = ["example.tld"]
    prog.passphrase = "foobar"
    prog.main([])
    expect(prog.passwords).to eq ["nj&xzO@hz&QvuoGY"]
    expect(prog.output.flatten).to eq [
      "# ok, checksum is 72eb36",
      "Reminder is: 72eb360a1000example.tld"
    ]
  end

  it "processes !! properly" do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld', '!!']
    prog.passphrase = "foobar"
    prog.main([])
    expect(prog.passwords).to eq [
      "nj&xzO@hz&QvuoGY",
      "nj&xzO@hz&QvuoGY"
    ]
    expect(prog.output.flatten).to eq [
      "# ok, checksum is 72eb36",
      "Reminder is: 72eb360a1000example.tld",
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
    expect(prog.passwords).to eq ["mJRUHjid"]
    expect(prog.output.flatten).to eq [
      "# ok, checksum is 72eb36",
      "Reminder is: 72eb360f0801example.tld"
    ]
  end

  it "processes command-line arguments properly" do
    prog = Daniel::MainProgram.new
    prog.lines = ["example.tld"]
    prog.passphrase = "foobar"
    prog.main(['-l8', '-v1', '-f15'])
    expect(prog.passwords).to eq ["mJRUHjid"]
    expect(prog.output.flatten).to eq [
      "# ok, checksum is 72eb36",
      "Reminder is: 72eb360f0801example.tld"
    ]
  end

  it "processes reminders properly" do
    prog = Daniel::MainProgram.new
    prog.lines = ["example.tld"]
    prog.passphrase = "foobar"
    prog.main(['72eb360f0801example.tld', '72eb360a1000example.tld'])
    expect(prog.passwords).to eq ['mJRUHjid', 'nj&xzO@hz&QvuoGY']
    expect(prog.output.flatten).to eq ["# ok, checksum is 72eb36"]
  end

  it "handles mismatched reminders properly" do
    prog = Daniel::MainProgram.new
    prog.lines = ["example.tld"]
    prog.passphrase = "foobar"
    expect {
      prog.main(['ffffff0f0801example.tld'])
    }.to raise_error(RuntimeError, /checksum mismatch/i)
  end

  it "handles loading the clipboard gem properly" do
    prog = Daniel::MainProgram.new
    prog.lines = ["example.tld"]
    prog.passphrase = "foobar"
    prog.main(['-p'])
    if prog.clipboard
      expect {
        Object.const_get('Clipboard')
      }.not_to raise_error
    else
      expect(prog.warnings.flatten).to eq [
        "Can't load clipboard gem; passwords will be printed"
      ]
    end
  end
end

#!/usr/bin/ruby
# encoding: UTF-8

require 'English'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

module Daniel
  class MainProgram
    attr_accessor :passphrase, :passwords, :lines, :output, :warnings
    attr_accessor :params, :clipboard

    def read_passphrase
      if @passphrase.is_a? Array
        @passphrase.shift
      else
        @passphrase
      end
    end

    def output_password(pass, _clipboard = false)
      @passwords ||= []
      @passwords << pass
    end

    def warn(*args)
      @warnings ||= []
      @warnings << args
    end

    def read_line
      fail EOFError if @lines.empty?
      @lines.shift
    end

    def puts(*args)
      @output ||= []
      @output << args
    end

    def print(*)
    end
  end
end

describe Daniel::MainProgram do
  it 'parses args correctly' do
    prog = Daniel::MainProgram.new
    prog.parse_args(%w(-l8 -v1 -f15))
    expect(prog.params.length).to eq 8
    expect(prog.params.version).to eq 1
    expect(prog.params.flags).to eq 15
  end

  it 'parses -m correctly' do
    prog = Daniel::MainProgram.new
    prog.parse_args(%w(-m))
    expect(prog.params.flags).to eq Daniel::Flags::REPLICATE_EXISTING
  end

  it 'refuses to accept -f and -m together' do
    prog = Daniel::MainProgram.new
    expect { prog.parse_args(%w(-m -f15)) }
      .to raise_error(RuntimeError, /can't.*both.*-m.*-f/i)
  end

  it 'generates reasonable output' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = 'foobar'
    prog.main([])
    expect(prog.passwords).to eq ['nj&xzO@hz&QvuoGY']
    expect(prog.output.flatten).to eq [
      '# ok, checksum is 72eb36',
      'Reminder is: 72eb360a1000example.tld'
    ]
  end

  it 'processes !! properly' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld', '!!']
    prog.passphrase = 'foobar'
    prog.main([])
    expect(prog.passwords).to eq [
      'nj&xzO@hz&QvuoGY',
      'nj&xzO@hz&QvuoGY'
    ]
    expect(prog.output.flatten).to eq [
      '# ok, checksum is 72eb36',
      'Reminder is: 72eb360a1000example.tld',
      'Reminder is: 72eb360a1000example.tld'
    ]
  end

  it 'processes commands properly' do
    prog = Daniel::MainProgram.new
    prog.lines = [
      '!length=8',
      '!version=1',
      '!flags=15',
      'example.tld'
    ]
    prog.passphrase = 'foobar'
    prog.main([])
    expect(prog.passwords).to eq ['mJRUHjid']
    expect(prog.output.flatten).to eq [
      '# ok, checksum is 72eb36',
      'Reminder is: 72eb360f0801example.tld'
    ]
  end

  it 'handles reloading the passphrase properly' do
    prog = Daniel::MainProgram.new
    prog.lines = [
      'example.tld',
      '!pass',
      'bar'
    ]
    prog.passphrase = %w(foobar foo)
    prog.main([])
    expect(prog.passwords).to eq [
      'nj&xzO@hz&QvuoGY',
      '3*Re7n*qcDDl9N6y'
    ]
    expect(prog.output.flatten).to eq [
      '# ok, checksum is 72eb36',
      'Reminder is: 72eb360a1000example.tld',
      '# ok, checksum is 8244c5',
      'Reminder is: 8244c50a1000bar'
    ]
  end

  it 'processes command-line arguments properly' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = 'foobar'
    prog.main(%w(-l8 -v1 -f15))
    expect(prog.passwords).to eq ['mJRUHjid']
    expect(prog.output.flatten).to eq [
      '# ok, checksum is 72eb36',
      'Reminder is: 72eb360f0801example.tld'
    ]
  end

  it 'processes reminders properly' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = 'foobar'
    prog.main(['72eb360f0801example.tld', '72eb360a1000example.tld'])
    expect(prog.passwords).to eq ['mJRUHjid', 'nj&xzO@hz&QvuoGY']
    expect(prog.output.flatten).to eq ['# ok, checksum is 72eb36']
  end

  it 'handles mismatched reminders properly' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = 'foobar'
    expect { prog.main(['ffffff0f0801example.tld']) }
      .to raise_error(RuntimeError, /checksum mismatch/i)
  end

  it 'processes reminders for existing passwords properly' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = 'foobar'
    prog.main(['72eb3620100095fb1346e2bec1670fb782fd51c8ac09example.tld'])
    expect(prog.passwords).to eq ['verylongpassword']
    expect(prog.output.flatten).to eq ['# ok, checksum is 72eb36']
  end

  it 'handles existing passwords properly' do
    prog = Daniel::MainProgram.new
    prog.lines = ['!flags=32', 'example.tld']
    prog.passphrase = %w(foobar verylongpassword verylongpassword)
    prog.main([])
    expect(prog.output.flatten).to eq [
      '# ok, checksum is 72eb36',
      'Reminder is: 72eb3620100095fb1346e2bec1670fb782fd51c8ac09example.tld'
    ]
  end

  it 'handles existing passwords properly with -m' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = %w(foobar verylongpassword verylongpassword)
    prog.main(%w(-m))
    expect(prog.output.flatten).to eq [
      '# ok, checksum is 72eb36',
      'Reminder is: 72eb3620100095fb1346e2bec1670fb782fd51c8ac09example.tld'
    ]
  end

  it 'handles mismatched passwords properly with -m' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = %w(foobar verylongpassword differentpasssword)
    prog.main(%w(-m))
    expect(prog.output.flatten).to eq [
      '# ok, checksum is 72eb36',
      "\nPassphrases did not match."
    ]
  end

  it 'handles loading the clipboard gem properly' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = 'foobar'
    prog.main(['-p'])
    if prog.clipboard
      expect { Object.const_get('Clipboard') }.not_to raise_error
    else
      expect(prog.warnings.flatten).to eq [
        "Can't load clipboard gem; passwords will be printed"
      ]
    end
  end
end

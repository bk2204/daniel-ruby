#!/usr/bin/ruby
# encoding: UTF-8

require 'English'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

module Daniel
  class MainProgram
    attr_accessor :passphrase, :passwords, :lines, :output, :warnings
    attr_accessor :params, :clipboard
    attr_writer :prompt

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

    def print(*args)
      # This has to include interactive because Ruby 1.8 does a tail-call
      # optimization.
      return unless caller(1).first =~ /in `(prompt|interactive)'/
      msg = args.join('').chomp
      @output ||= []
      @output << msg unless msg.strip.empty?
    end
  end
end

def human_readable(msgs)
  result = msgs.flatten.map do |m|
    case m.rstrip
    when ':master-password?'
      'Please enter your master password: '
    when /\A:checksum (.*)\z/
      "# ok, checksum is #{Regexp.last_match[1]}"
    when /\A:reminder (.*)\z/
      "Reminder is: #{Regexp.last_match[1]}"
    end
  end
  result.select { |m| !m.nil? }
end

def interactive(msgs)
  result = msgs.flatten.map do |m|
    case m.rstrip
    when ':master-password?'
      'Please enter your master password: '
    when /\A:checksum (.*)\z/
      "# ok, checksum is #{Regexp.last_match[1]}"
    when /\A:reminder (.*)\z/
      "Reminder is: #{Regexp.last_match[1]}"
    when ':code?'
      'Enter code: '
    when ':existing?'
      'Enter existing passphrase: '
    end
  end
  result.select { |m| !m.nil? }
end

def machine_readable(msgs)
  msgs.flatten.map { |m| m.gsub('?', '? ') }
end

describe Daniel::MainProgram do
  it 'parses args correctly' do
    prog = Daniel::MainProgram.new
    prog.send(:parse_args, %w(-l8 -v1 -f15))
    expect(prog.params.length).to eq 8
    expect(prog.params.version).to eq 1
    expect(prog.params.flags).to eq 15
  end

  it 'parses -m correctly' do
    prog = Daniel::MainProgram.new
    prog.send(:parse_args, %w(-m))
    expect(prog.params.flags).to eq Daniel::Flags::REPLICATE_EXISTING
  end

  it 'refuses to accept -f and -m together' do
    prog = Daniel::MainProgram.new
    expect { prog.send(:parse_args, %w(-m -f15)) } \
      .to raise_error(RuntimeError, /can't.*both.*-m.*-f/i)
  end

  [
    ['', method(:human_readable), %w(), :human],
    [' (machine-readable)', method(:machine_readable), %w(-r)],
    [' (interactive)', method(:interactive), %w(), :interactive]
  ].each do |(msg, func, args, type)|
    it "generates reasonable output#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = ['example.tld']
      prog.passphrase = 'foobar'
      prog.prompt = type
      prog.main(args)
      expect(prog.passwords).to eq ['nj&xzO@hz&QvuoGY']
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36',
        ':code?',
        ':reminder 72eb360a1000example.tld',
        ':code?'
      ]
    end

    it "processes !! properly#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = ['example.tld', '!!']
      prog.passphrase = 'foobar'
      prog.prompt = type
      prog.main(args)
      expect(prog.passwords).to eq [
        'nj&xzO@hz&QvuoGY',
        'nj&xzO@hz&QvuoGY'
      ]
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36',
        ':code?',
        ':reminder 72eb360a1000example.tld',
        ':code?',
        ':reminder 72eb360a1000example.tld',
        ':code?'
      ]
    end

    it "processes commands properly#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = [
        '!length=8',
        '!version=1',
        '!flags=15',
        'example.tld'
      ]
      prog.passphrase = 'foobar'
      prog.prompt = type
      prog.main(args)
      expect(prog.passwords).to eq ['mJRUHjid']
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36',
        ':code?',
        ':code?',
        ':code?',
        ':code?',
        ':reminder 72eb360f0801example.tld',
        ':code?'
      ]
    end

    it "handles reloading the passphrase properly#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = [
        'example.tld',
        '!pass',
        'bar'
      ]
      prog.passphrase = %w(foobar foo)
      prog.prompt = type
      prog.main(args)
      expect(prog.passwords).to eq [
        'nj&xzO@hz&QvuoGY',
        '3*Re7n*qcDDl9N6y'
      ]
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36',
        ':code?',
        ':reminder 72eb360a1000example.tld',
        ':code?',
        ':master-password?',
        ':checksum 8244c5',
        ':code?',
        ':reminder 8244c50a1000bar',
        ':code?'
      ]
    end

    it "processes command-line arguments properly#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = ['example.tld']
      prog.passphrase = 'foobar'
      prog.prompt = type
      prog.main(%w(-l8 -v1 -f15) + args)
      expect(prog.passwords).to eq ['mJRUHjid']
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36',
        ':code?',
        ':reminder 72eb360f0801example.tld',
        ':code?'
      ]
    end

    it "processes reminders properly#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = ['example.tld']
      prog.passphrase = 'foobar'
      prog.prompt = type
      prog.main(args + ['72eb360f0801example.tld', '72eb360a1000example.tld'])
      expect(prog.passwords).to eq ['mJRUHjid', 'nj&xzO@hz&QvuoGY']
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36',
      ]
    end

    it "handles mismatched reminders properly#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = ['example.tld']
      prog.passphrase = 'foobar'
      prog.prompt = type
      expect { prog.main(args + ['ffffff0f0801example.tld']) } \
        .to raise_error(RuntimeError, /checksum mismatch/i)
    end

    it "processes reminders for existing passwords properly#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = ['example.tld']
      prog.passphrase = 'foobar'
      prog.prompt = type
      prog.main(args +
                ['72eb3620100095fb1346e2bec1670fb782fd51c8ac09example.tld'])
      expect(prog.passwords).to eq ['verylongpassword']
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36'
      ]
    end

    it "handles existing passwords properly#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = ['!flags=32', 'example.tld']
      prog.passphrase = %w(foobar verylongpassword verylongpassword)
      prog.prompt = type
      prog.main(args)
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36',
        ':code?',
        ':code?',
        ':existing?',
        ':reminder 72eb3620100095fb1346e2bec1670fb782fd51c8ac09example.tld',
        ':code?'
      ]
    end

    it "handles existing passwords properly with -m#{msg}" do
      prog = Daniel::MainProgram.new
      prog.lines = ['example.tld']
      prog.passphrase = %w(foobar verylongpassword verylongpassword)
      prog.prompt = type
      prog.main(%w(-m) + args)
      expect(prog.output.flatten).to eq func.call [
        ':master-password?',
        ':checksum 72eb36',
        ':code?',
        ':existing?',
        ':reminder 72eb3620100095fb1346e2bec1670fb782fd51c8ac09example.tld',
        ':code?'
      ]
    end
  end

  it 'handles mismatched passwords properly with -m' do
    prog = Daniel::MainProgram.new
    prog.lines = ['example.tld']
    prog.passphrase = %w(foobar verylongpassword differentpasssword)
    prog.prompt = :interactive
    prog.main(%w(-m))
    expect(prog.output.flatten).to eq [
      'Please enter your master password: ',
      '# ok, checksum is 72eb36',
      'Enter code: ',
      'Enter existing passphrase: ',
      "\nPassphrases did not match.",
      'Enter code: '
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

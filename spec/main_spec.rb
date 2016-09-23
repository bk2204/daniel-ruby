#!/usr/bin/ruby
# encoding: UTF-8

require 'spec_helper'

module Daniel
  # The main program class, but slightly more open.
  class MainProgram
    attr_accessor :passphrase, :passwords, :lines, :output, :warnings
    attr_accessor :params, :clipboard
    attr_writer :prompt, :format

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
      raise EOFError if @lines.empty?
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

def process_message_human(msg)
  strings = {
    ':checksum' => '# ok, checksum is',
    ':reminder' => 'Reminder is:',
    ':version' => 'Version:',
    ':length' => 'Length:',
    ':password-version' => 'Password version:',
    ':iterations' => 'Iterations:',
    ':mask' => 'Mask:',
    ':mac' => 'MAC:',
    ':salt' => 'Salt:',
    ':flags' => 'Flags:',
    ':code' => 'Code:'
  }
  s = msg.rstrip
  case s
  when ':master-password?'
    'Please enter your master password: '
  when /\A(:(?:mask|mac|salt)) (.*)\z/
    str, val = Regexp.last_match[1..2]
    "#{strings[str]} #{Daniel::Util.to_hex(CGI.unescape(val))}"
  when ':code?'
    nil
  else
    if s.start_with?(*strings.keys)
      s.sub(/\A(:[a-z-]+) (.*)\z/) do
        str, rest = Regexp.last_match[1..2]
        "#{strings[str]} #{rest}"
      end
    end
  end
end

def process_message_interactive(msg)
  case msg.rstrip
  when ':code?'
    'Enter code: '
  when ':existing?'
    'Enter existing passphrase: '
  else
    process_message_human(msg)
  end
end

def human_readable(msgs)
  msgs.flatten.map { |m| process_message_human(m) }.select { |m| !m.nil? }
end

def interactive(msgs)
  msgs.flatten.map { |m| process_message_interactive(m) }.select { |m| !m.nil? }
end

def machine_readable(msgs)
  msgs.flatten.map { |m| m.gsub('?', '? ') }
end

def parse_human(msgs)
  msgs.map do |msg|
    msg.sub(/# ok, checksum is (.*)/, 'Checksum: \1')
  end
end

def with_config
  key = 'XDG_CONFIG_HOME'
  old = ENV[key]
  ENV[key] = File.join(File.dirname(__FILE__), 'fixtures')
  begin
    ret = yield
  ensure
    ENV[key] = old
  end
  ret
end

if RUBY_ENGINE != 'opal'
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
        .to raise_error(OptionParser::InvalidArgument, /can't.*both.*-m.*-f/i)
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
        prog.main(args + %w(-f10))
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
        prog.main(args + %w(-f10))
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

      it "processes reminder commands properly#{msg}" do
        prog = Daniel::MainProgram.new
        prog.lines = [
          '!rem=72eb360f0801example.tld',
          '!reminder=72eb360f0801example.tld'
        ]
        prog.passphrase = 'foobar'
        prog.prompt = type
        prog.main(args)
        expect(prog.passwords).to eq(['mJRUHjid'] * 2)
        expect(prog.output.flatten).to eq func.call [
          ':master-password?',
          ':checksum 72eb36',
          ':code?',
          ':code?',
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
        prog.main(args + %w(-f10))
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
          ':checksum 72eb36'
        ]
      end

      it "processes reminders properly with config#{msg}" do
        with_config do
          prog = Daniel::MainProgram.new
          prog.lines = ['example.tld']
          prog.passphrase = 'foobar'
          prog.prompt = type
          prog.main(args + ['72eb360f0801example.tld',
                            '72eb360a1000example.tld'])
          expect(prog.passwords).to eq ['mJRUHjid', 'nj&xzO@hz&QvuoGY']
          expect(prog.output.flatten).to eq func.call [
            ':master-password?',
            ':checksum 72eb36'
          ]
        end
      end

      it "honors theme properly#{msg}" do
        with_config do
          prog = Daniel::MainProgram.new
          prog.lines = ['example.tld']
          prog.passphrase = 'foobar'
          prog.prompt = type
          prog.main(args + %w(-t throwaway))
          expect(prog.passwords).to eq ['mJRUHjid']
          expect(prog.output.flatten).to eq func.call [
            ':master-password?',
            ':checksum 72eb36',
            ':code?',
            ':reminder 72eb360f0801example.tld',
            ':code?'
          ]
        end
      end

      it "handles mismatched reminders properly#{msg}" do
        prog = Daniel::MainProgram.new
        prog.lines = ['example.tld']
        prog.passphrase = 'foobar'
        prog.prompt = type
        expect { prog.main(args + ['ffffff0f0801example.tld']) } \
          .to raise_error(Daniel::ChecksumMismatchError, /checksum mismatch/i)
      end

      it "allows all-null reminders properly#{msg}" do
        prog = Daniel::MainProgram.new
        prog.lines = ['example.tld']
        prog.passphrase = 'foobar'
        prog.prompt = type
        expect { prog.main(args + ['0000000f0801example.tld']) } \
          .not_to raise_error
        expect(prog.passwords).to eq ['mJRUHjid']
        expect(prog.output.flatten).to eq func.call [
          ':master-password?',
          ':checksum 72eb36'
        ]
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

      it "handles printing passwords in plain format correctly#{msg}" do
        prog = Daniel::MainProgram.new
        prog.lines = ['example.tld']
        prog.passphrase = %w(foobar)
        prog.prompt = type
        prog.main(%w(-P plain) + args +
                  %w(72eb36200900b3f70f5aefa1df6c1aexample.tld))
        expect(prog.output.flatten).to eq func.call [
          ':master-password?',
          ':checksum 72eb36'
        ]
        expect(prog.passwords).to eq %w(Pineapple)
      end

      it "handles printing passwords in bubblebabble format correctly#{msg}" do
        prog = Daniel::MainProgram.new
        prog.lines = ['example.tld']
        prog.passphrase = %w(foobar)
        prog.prompt = type
        prog.main(%w(-P bubblebabble) + args +
                  %w(72eb36200900b3f70f5aefa1df6c1aexample.tld))
        expect(prog.output.flatten).to eq func.call [
          ':master-password?',
          ':checksum 72eb36'
        ]
        expect(prog.passwords).to eq %w(xigak-nyryk-humil-bosek-sonax)
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

      it 'parses existing-password reminders correctly' do
        reminder = '72eb36200f045ed8d92f9309c10059ee79f5d50266example.tld'
        prog = Daniel::MainProgram.new
        prog.prompt = type
        prog.main(%w(-a) + args + [reminder])
        expect(prog.output.flatten).to eq parse_human func.call [
          ":reminder #{reminder}",
          ':version 0',
          ':length 15',
          ':password-version 4',
          ':flags 32 replicate-existing',
          ':iterations 1024',
          ':checksum 72eb36',
          ':mask %5E%D8%D9%2F%93%09%C1%00Y%EEy%F5%D5%02f',
          ':code example.tld'
        ]
      end

      it "produces expected output type for arbitrary bytes#{msg}" do
        prog = Daniel::MainProgram.new
        prog.lines = ['!flags=0x80', 'example.tld']
        prog.passphrase = 'foobar'
        prog.prompt = type
        prog.main(args)
        expect(prog.output.flatten).to eq func.call [
          ':master-password?',
          ':checksum 72eb36',
          ':code?',
          ':code?',
          ':reminder 72eb3681001000example.tld',
          ':code?'
        ]
        output = if type
                   %w(0e187863b62ca736f75c84a6265985f5)
                 else
                   [Daniel::Util.to_binary(
                     "\x0E\x18xc\xB6\x2C\xA76\xF7\x5C\x84\xA6\x26Y\x85\xF5"
                   )]
                 end
        expect(prog.passwords).to eq output
      end

      # Master password is 'barbaz'.
      it 'parses generated-password reminders correctly' do
        reminder = 'd90403050d816ddefault.example.com'
        prog = Daniel::MainProgram.new
        prog.prompt = type
        prog.main(%w(-a) + args + [reminder])
        expect(prog.output.flatten).to eq parse_human func.call [
          ":reminder #{reminder}",
          ':version 0',
          ':length 13',
          ':password-version 237',
          ':flags 5 no-numbers no-symbols-top',
          ':iterations 1024',
          ':checksum d90403',
          ':code default.example.com'
        ]
      end

      # Synthesized, no actual password.
      it 'parses v1 generated-password reminders correctly' do
        reminder = '98765460018162' \
          'eyJhbGciOiJIUzI1NiIsImtpZCI6IjE6ODE5Mjo5ODc2NTQ6QUFBQUFBQUFBQUFBI' \
          'iwidHlwIjoiSldUIn0.eyJjb2RlIjoiZXhhbXBsZS5jb20iLCJmbGciOjk2LCJsZW' \
          '4iOjEyLCJtc2siOiIvLy8vLy8vLy8vLy8vLy8vIiwidmVyIjoyfQ.ubYHWboinhps' \
          'FBqAgTgCuovi7YdgfJzmtIJtvWrXSv0example.com'
        prog = Daniel::MainProgram.new
        prog.prompt = type
        prog.main(%w(-a) + args + [reminder])
        expect(prog.output.flatten).to eq parse_human func.call [
          ":reminder #{reminder}",
          ':version 1',
          ':length 12',
          ':password-version 2',
          ':flags 96 replicate-existing explicit-version',
          ':iterations 8192',
          ':salt %00%00%00%00%00%00%00%00%00',
          ':checksum 987654',
          ':mask %FF%FF%FF%FF%FF%FF%FF%FF%FF%FF%FF%FF',
          ':mac ' \
            '%B9%B6%07Y%BA%22%9E%1Al%14%1A%80%818%02' \
            '%BA%8B%E2%ED%87%60%7C%9C%E6%B4%82m%BDj%D7J%FD',
          ':code example.com'
        ]
      end

      it "sets explicit version flag correctly#{msg}" do
        reminder = '72eb36' \
          '4e01812feyJhbGciOiJIUzI1NiIsImtpZCI6IjE6MTAyNDo3MmViMzYiLCJ0eXAiO' \
          'iJKV1QifQ.eyJjb2RlIjoiZXhhbXBsZS5jb20iLCJmbGciOjc4LCJsZW4iOjE2LCJ' \
          '2ZXIiOjB9.SXKBiXhyBTFqoEcV3Nh6WprnTOCVWT3f6Rv0eHXn_Jkexample.com'
        prog = Daniel::MainProgram.new
        prog.lines = ['example.com']
        prog.passphrase = 'foobar'
        prog.prompt = type
        prog.main(%w(--format-version 1 -f 0x0e) + args)
        expect(prog.passwords).to eq ['YcYAWNpjt2qqzKvw']
        expect(prog.output.flatten).to eq func.call [
          ':master-password?',
          ':checksum 72eb36',
          ':code?',
          ":reminder #{reminder}",
          ':code?'
        ]
      end
    end

    it 'produces proper estimate output' do
      prog = Daniel::MainProgram.new
      prog.main(%w(-e -f10))
      expect(prog.output.flatten).to eq [
        '16 characters; 72 possible (6.17 bpc); 98.72 bits of entropy'
      ]
    end

    it 'produces proper estimate output (machine-readable)' do
      prog = Daniel::MainProgram.new
      prog.main(%w(-e -f10 -r))
      expect(prog.output.flatten.map { |s| s.split("\n") }.flatten).to eq [
        ':length 16',
        ':possible-char 72',
        ':bits-per-char 6.17',
        ':bits-total 98.72'
      ]
    end

    it 'encodes text properly with format plain and non-binary data' do
      prog = Daniel::MainProgram.new
      prog.format = :plain
      ['te?xt', 'La langue française', "\x00hello, world!\x80"].each do |s|
        expect(prog.send(:encode, s, false)).to eq s
      end
    end

    it 'hex encodes text properly with format plain and binary data' do
      prog = Daniel::MainProgram.new
      prog.format = :plain
      ['te?xt', 'La langue française', "\x00hello, world!\x80"].each do |s|
        expect(prog.send(:encode, s, true)).to eq Daniel::Util.to_hex(s)
      end
    end

    it 'does not encode text properly with non-plain format and binary data' do
      prog = Daniel::MainProgram.new
      prog.format = :bubblebabble
      ['te?xt', 'La langue française', "\x00hello, world!\x80"].each do |s|
        expected = Daniel::Formatter.bubblebabble(s)
        expect(prog.send(:encode, s, true)).to eq expected
      end
    end

    [
      [16, 72, 6.17, 98.72, 0x0a],
      [12, 95, 6.57, 78.84, 0x00]
    ].each do |(len, possible, bpc, bits, flags)|
      it 'produces proper estimates' do
        prog = Daniel::MainProgram.new
        prog.main(['-e', "-l#{len}", "-f#{flags}"])
        res = "#{len} characters; #{possible} possible (#{bpc} bpc); \
#{bits} bits of entropy"
        expect(prog.output.flatten).to eq [res]
      end

      it 'produces proper estimates (machine-readable)' do
        prog = Daniel::MainProgram.new
        prog.main(['-e', '-r', "-l#{len}", "-f#{flags}"])
        expect(prog.output.flatten.map { |s| s.split("\n") }.flatten).to eq [
          ":length #{len}",
          ":possible-char #{possible}",
          ":bits-per-char #{bpc}",
          ":bits-total #{bits}"
        ]
      end
    end

    it 'throws an exception with an invalid password format' do
      prog = Daniel::MainProgram.new
      expect { prog.main(%w(-P bizarre)) }.to \
        raise_error(OptionParser::InvalidArgument, /not.*valid/)
    end

    it 'throws an exception when -t is used with no config' do
      prog = Daniel::MainProgram.new
      expect { prog.main(%w(-t throwaway)) }.to \
        raise_error(OptionParser::InvalidArgument, /not.*valid/)
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
end

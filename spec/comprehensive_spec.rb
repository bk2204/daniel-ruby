# encoding: UTF-8

require 'spec_helper'

def entries
  # TODO: implement IO#each_line as a polyfill
  return [] if ::RUBY_ENGINE == 'opal'
  f = File.new(File.join(File.dirname(__FILE__), 'fixtures', 'reminders.csv'),
               'r')
  f.each_line.map do |line|
    next if /^\s*#/ =~ line
    line.chomp.split(':').map { |s| unescape(s) }
  end.reject(&:nil?)
end

def unescape(s)
  # Basically, CGI.unescape.
  s = s.gsub(/%([0-9a-fA-F]{2})/) do
    Daniel::Util.from_hex(Regexp.last_match[1])
  end
  Daniel::Util.to_binary(s)
end

describe Daniel::PasswordGenerator do
  def known_failure(pass)
    ::RUBY_ENGINE == 'opal' && !pass.bytes.select { |b| b > 0x7f }.empty?
  end

  entries.each do |entry|
    master, csum, flags, ver, code, reminder, result, description = *entry
    csum = Daniel::Util.to_binary(csum)
    result = Daniel::Util.to_binary(result)
    flags = flags.unpack('w')[0]
    ver = ver.unpack('w')[0]

    it "gives the expected checksum for #{description}" do
      pending 'Opal encoding issues' if known_failure(master)

      gen = Daniel::PasswordGenerator.new master
      expect(gen.checksum).to eq csum
    end

    it "gives the expected password for #{description}" do
      pending 'Opal encoding issues' if known_failure(master)

      gen = Daniel::PasswordGenerator.new master
      rem = gen.parse_reminder(reminder)
      expect(gen.generate_from_reminder(reminder)).to eq(result)
      expect(gen.generate_from_reminder(rem)).to eq(result)
    end

    if /^000000/ =~ reminder
      it "marks all-zero reminders as anonymous for #{description}" do
        pending 'Opal encoding issues' if known_failure(master)

        gen = Daniel::PasswordGenerator.new master
        rem = gen.parse_reminder(reminder)
        expect(rem.anonymous?).to be true
      end
    else
      it "round-trips the reminder correctly for #{description}" do
        pending 'Opal encoding issues' if known_failure(master)

        gen = Daniel::PasswordGenerator.new master
        rem = gen.parse_reminder(reminder)
        expect(gen.reminder(rem.code, rem.params, rem.mask)).to eq(reminder)
      end
    end

    it "parses the reminder correctly for #{description}" do
      pending 'Opal encoding issues' if known_failure(master)

      gen = Daniel::PasswordGenerator.new master
      rem = gen.parse_reminder(reminder)
      expect(rem.code).to eq code
      expect(rem.params.flags).to eq flags
      expect(rem.params.version).to eq ver
    end

    it "round-trips passwords correctly for #{description}" do
      pending 'Opal encoding issues' if known_failure(master)

      gen = Daniel::PasswordGenerator.new master
      rem = gen.parse_reminder(reminder)
      expect(gen.generate(rem.code, rem.params, rem.mask)).to eq(result)
    end
  end
end

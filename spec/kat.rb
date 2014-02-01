#!/usr/bin/ruby
# encoding: UTF-8

$:.unshift File.join(File.dirname(__FILE__), '..')

load 'daniel'

describe Daniel::PasswordGenerator do
  [
    ["foo", "bar", "3*Re7n*qcDDl9N6y", "8244c50a1000bar"],
    ["foo", "baz", "Dp4iWIX26UwV55N(", "8244c50a1000baz"],
    # Test Unicode.
    ["La République française", "la-france", "w^O)Vl7V0O&eEa^H",
     "55b1d40a1000la-france"],
  ].each do |items|
    master, code, result, reminder = items
    it "gives the expected password for #{master}, #{code}" do
      gen = Daniel::PasswordGenerator.new master
      gen.generate(code, Daniel::Parameters.new).should == result
    end
    it "gives the expected reminder for #{master}, #{code}" do
      gen = Daniel::PasswordGenerator.new master
      gen.reminder(code, Daniel::Parameters.new).should == reminder
    end
    it "gives the expected password for #{master}, #{code} reminder" do
      gen = Daniel::PasswordGenerator.new master
      gen.generate_from_reminder(reminder).should == result
    end
  end
end

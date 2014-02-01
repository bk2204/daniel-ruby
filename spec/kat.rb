#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), '..')

load 'daniel'

describe Daniel::PasswordGenerator do
	it "gives the expected password for foo, bar" do
		gen = Daniel::PasswordGenerator.new "foo"
		gen.generate("baz", Daniel::Parameters.new).should == "Dp4iWIX26UwV55N("
	end
	it "gives the expected reminder for foo, bar" do
		gen = Daniel::PasswordGenerator.new "foo"
		gen.reminder("baz", Daniel::Parameters.new).should == "8244c50a1000baz"
	end
	it "gives the expected password for foo, bar reminder" do
		gen = Daniel::PasswordGenerator.new "foo"
		gen.generate_from_reminder("8244c50a1000baz").should ==
      "Dp4iWIX26UwV55N("
	end
end

#!/usr/bin/ruby
# encoding: UTF-8

require File.join(File.dirname(__FILE__), 'spec_helper')

if RUBY_ENGINE != 'opal'
  require 'daniel/throwaway/main'

  class MockMainProgram < Daniel::ThrowawayPass::MainProgram
    def initialize(io)
      @io = io
      super()
    end

    def initialize_variables
      file = File.join(File.dirname(__FILE__), %w(fixtures daniel throwaway.yaml))
      @config = Daniel::Configuration.new(File.new(file, 'r'))
      @clipboard = false
    end
  end

  describe Daniel::ThrowawayPass::MainProgram do
    it 'should generate valid passwords' do
      io = StringIO.new('', 'w')
      prog = MockMainProgram.new(io)
      prog.main(%w(bar baz))
      expect(io.string).to eq "3*Re7n*qcDDl9N6y\nDp4iWIX26UwV55N("
    end
  end
end

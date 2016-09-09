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
      prog.main(%w(-p bar baz))
      expect(io.string).to eq "3*Re7n*qcDDl9N6y\nDp4iWIX26UwV55N("
    end

    it 'should generate machine-readable passwords with -r' do
      io = StringIO.new('', 'w')
      prog = MockMainProgram.new(io)
      prog.main(%w(-pr bar baz))
      expect(io.string).to eq "3%2ARe7n%2AqcDDl9N6y\nDp4iWIX26UwV55N%28"
    end

    it 'should generate different passwords with -v' do
      io = StringIO.new('', 'w')
      prog = MockMainProgram.new(io)
      prog.main(%w(-p -v1 bar baz))
      expect(io.string).to eq "YME0d&bl2N&#tk*g\n&@r6A8BdRQgJeY@u"
    end
  end
end

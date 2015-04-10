$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

RUBY_ENGINE = 'unknown' unless defined?(RUBY_ENGINE)

# This has to two separate if statements or Opal won't ignore it.
if RUBY_ENGINE != 'opal'
  # Coverage has to go before other requires.
  if ENV['COVERAGE']
    require 'simplecov'

    SimpleCov.start 'rails'
  end
end

require 'daniel'

RSpec.configure do |c|
  c.full_backtrace = true
end

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

RUBY_ENGINE = 'unknown'.freeze unless defined?(RUBY_ENGINE)

# This has to two separate if statements or Opal won't ignore it.
if RUBY_ENGINE != 'opal'
  # Coverage has to go before other requires.
  if ENV['COVERAGE']
    require 'simplecov'
    require 'simplecov-html'

    SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
    SimpleCov.start 'rails'
  end

  require 'tmpdir'
  require 'daniel/converter'
end

# Ensure we don't load the user's config.
ENV['XDG_CONFIG_HOME'] = File.dirname(__FILE__)

require 'daniel'

RSpec.configure do |c|
  c.full_backtrace = true
end

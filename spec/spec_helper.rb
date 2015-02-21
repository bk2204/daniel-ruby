$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

# This has to two separate if statements or Opal won't ignore it.
if RUBY_ENGINE != 'opal'
  if ENV['COVERAGE']
    require 'simplecov'

    SimpleCov.start 'rails'
  end
end

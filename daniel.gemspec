require './lib/daniel'

Gem::Specification.new do |s|
  s.name        = 'daniel'
  s.version     = Daniel::Version.to_s
  s.author      = 'brian m. carlson'
  s.email       = 'sandals@crustytoothpaste.net'
  s.homepage    = 'https://github.com/bk2204/daniel-ruby'
  s.summary     = 'An easy-to-use password generator'
  s.license     = 'MIT'
  s.description = <<-EOD
    daniel is a password tool that can generate new passwords or store existing
    ones and reproduce either with a small reminder string and a master
    password.
  EOD

  s.add_dependency('io-console') if ::RUBY_VERSION < '1.9'
  s.add_dependency('twofish', '~> 1.0.7')
  s.add_dependency('clipboard', '~> 1.0.6')

  s.add_development_dependency('rake', '~> 10.0')
  s.add_development_dependency('rspec', '~> 2.11')
  s.add_development_dependency('rubocop', '~> 0.42.0')

  if ::RUBY_VERSION >= '2.2'
    s.add_dependency('opal', '~> 0.10.1')
    s.add_development_dependency('opal-rspec', '~> 0.6.0')
  end

  s.files  = %w(LICENSE Rakefile README.adoc doc/daniel.adoc)
  s.files += Dir.glob('bin/*')
  # Update this to lib/**/*.rb when daniel/credential is ready to go.
  s.files += Dir.glob('lib/*.rb')
end

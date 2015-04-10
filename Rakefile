require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/*.rb'
end

possible = []

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
  possible << :rubocop
rescue LoadError # rubocop:disable Lint/HandleExceptions
end

begin
  require 'opal'
  require 'opal-rspec'
  require 'opal/rspec/rake_task'
  Opal::RSpec::RakeTask.new do |t|
    t.append_path 'lib'
  end
  possible << :"opal:rspec"
rescue LoadError => e
  $stderr.puts e
end

begin
  require 'opal'
  task :"opal:build" => :build_setup do
    Opal.append_path 'lib'
    Opal.use_gem 'opal-jquery'
    dest = 'build/html'
    files = { 'daniel' => 'daniel', 'daniel-page' => 'daniel/opal/page' }
    files.each do |js, ruby|
      File.binwrite "#{dest}/#{js}.js", Opal::Builder.build(ruby).to_s
    end
  end
  possible << :"opal:build"
rescue LoadError => e
  $stderr.puts e
end

task :build_setup do
  %w(build build/html).each do |dir|
    Dir.mkdir dir unless Dir.exists? dir
  end
end

task :html => [:build_setup, :"opal:build"] do
  %w(daniel.xhtml daniel.css).each do |file|
    cp "html/#{file}", 'build/html'
  end
end

task :build => [:"opal:build", :html]
task :all => [:spec] + possible
task :default => :spec

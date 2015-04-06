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
  task :"opal:build" do
    Opal.append_path 'lib'
    File.binwrite 'html/daniel.js', Opal::Builder.build('daniel').to_s
  end
  possible << :"opal:build"
rescue LoadError => e
  $stderr.puts e
end

task :all => [:spec] + possible
task :default => :spec

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
  require 'net/http'
  Opal::RSpec::RakeTask.new do |serv, task|
    serv.append_path 'lib'
    task.runner = :node
  end
  possible << :"opal:rspec"
rescue LoadError => e
  $stderr.puts e
end

begin
  opal_dest = 'build/html'
  opal_files = {
    'daniel' => 'daniel',
    'daniel-converter' => 'daniel/converter',
    'daniel-page' => 'daniel/opal/page'
  }
  opal_files.each do |js, ruby|
    file "#{opal_dest}/#{js}.js" => ['build/html', "lib/#{ruby}.rb"] do |t|
      require 'opal'
      require 'opal-jquery'

      next unless t.needed?
      Opal.append_path 'lib'
      Opal.use_gem 'opal-jquery'
      File.binwrite "#{opal_dest}/#{js}.js", Opal::Builder.build(ruby).to_s
    end
  end
  task :"opal:build" => opal_files.keys.map { |f| "#{opal_dest}/#{f}.js" }
  possible << :build
rescue LoadError => e
  $stderr.puts e
end

file 'build/html' do
  %w[build build/html].each do |dir|
    Dir.mkdir dir unless Dir.exist? dir
  end
end

task :html => ['build/html', :"opal:build"] do
  %w[daniel.xhtml daniel.css].each do |file|
    cp "html/#{file}", 'build/html'
  end
end

doc_src = Rake::FileList['doc/*.adoc']
doc_obj = doc_src.map { |f| f.gsub(/\.adoc\z/, '.1') }

rule '.1' => '.adoc' do |t|
  sh "asciidoctor -b manpage -o #{t.name} #{t.source}"
end

task :build => %i[opal:build html]
task :doc => doc_obj
task :all => [:spec] + possible
task :default => :all

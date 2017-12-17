require 'digest'
require 'net/http'
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

def handle_response(resp, path, limit)
  case resp
  when Net::HTTPSuccess
    File.open path, 'wb' do |f|
      resp.read_body do |c|
        f.write c
      end
    end
  when Net::HTTPRedirection
    fetch(URI(resp['location']), path, limit - 1)
  else
    raise "Unknown response: #{resp}"
  end
end

def fetch(uri, path, limit = 10)
  raise 'Too many redirects' if limit.zero?

  Net::HTTP.start(uri.host, uri.port,
                  :use_ssl => (uri.scheme == 'https')) do |http|
    req = Net::HTTP::Get.new(uri)
    http.request req do |resp|
      handle_response(resp, path, limit)
    end
  end
end

def verify_hash(path, tmp_path, hash)
  h = Digest::SHA256.file tmp_path
  res = h.hexdigest
  if res != hash
    rm tmp_path
    raise "Hash mismatch: expected #{hash}; got #{res}"
  end
  mv tmp_path, path
  true
end

SJCL_VER = '1.0.7'.freeze
file 'tmp/sjcl.tar.gz' => 'tmp' do |t|
  uri = "https://github.com/bitwiseshiftleft/sjcl/archive/#{SJCL_VER}.tar.gz"
  uri = URI(uri)
  hash = 'ccc4032cdd05c38ce3679e7dcd80c3e04162b783ea356c812591dae9a1e56b9b'
  path = t.name
  fetch(uri, "#{path}.tmp")
  verify_hash(path, "#{path}.tmp", hash)
end

file 'tmp' do
  Dir.mkdir 'tmp'
end

task :sjcl => 'tmp/sjcl.tar.gz' do
  path = File.realpath('tmp/sjcl.tar.gz')
  coredir = "sjcl-#{SJCL_VER}/core/"
  Dir.chdir 'tmp' do
    sh 'tar', '-xvzf', path, coredir
  end
  cp Dir["#{coredir}/*"], 'lib/daniel/opal'
end

manpage_src = Rake::FileList['doc/*.adoc']
manpages = manpage_src.map { |f| f.gsub(/\.adoc\z/, '.1') }

rule '.1' => '.adoc' do |t|
  sh "asciidoctor -b manpage -o #{t.name} #{t.source}"
end

task :yard do
  sh 'yard'
end

task :build => %i[opal:build html]
task :doc => [:yard] + manpages
task :all => [:spec] + possible
task :default => :all

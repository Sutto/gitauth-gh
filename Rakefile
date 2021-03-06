require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'
require File.join(File.dirname(__FILE__), "lib", "gitauth", "gh_mirror")

spec = Gem::Specification.new do |s|
  s.name        = 'gitauth-gh'
  s.email       = 'sutto@sutto.net'
  s.homepage    = 'http://sutto.net/'
  s.authors     = ["Darcy Laycock"]
  s.version     = GitAuth::GitHubMirror.version(ENV['RELEASE'].blank?)
  s.summary     = "Automatic mirror for github -> gitauth"
  s.files       = FileList["{bin,lib}/**/*"].to_a
  s.platform    = Gem::Platform::RUBY
  s.executables = FileList["bin/*"].map { |f| File.basename(f) }
  s.add_dependency "brownbeagle-gitauth", ">= 0.0.4.5"
  s.add_dependency "httparty"
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

task :gemspec do
  File.open("gitauth-gh.gemspec", "w+") { |f| f.puts spec.to_ruby }
end

def gemi(name, version)
  command = "gem install #{name} --version '#{version}' --source http://gems.github.com"
  puts ">> #{command}"
  system "#{command} 1> /dev/null 2> /dev/null"
end

task :install_dependencies do
  spec.dependencies.each do |dependency|
    gemi dependency.name, dependency.requirement_list.first
  end
end

task :check_dirty do
  if `git status`.include? 'added to commit'
    puts "You have uncommited changes. Please commit them first"
    exit!
  end
end

task :tag => :check_dirty do
  version = GitAuth::GitHubMirror.version(ENV['RELEASE'].blank?)
  command = "git tag -a v#{version} -m 'Code checkpoint for v#{version}'"
  puts ">> #{command}"
  system command
end

task :commit_gemspec => [:check_dirty, :gemspec] do
  command = "git commit -am 'Generate gemspec for v#{GitAuth::GitHubMirror.version(ENV['RELEASE'].blank?)}'"
  puts ">> #{command}"
  system command
end

task :release => [:commit_gemspec, :tag] do
  puts ">> git push"
  system "git push"
  system "git push --tags"
  puts "New version released."
end

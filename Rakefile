# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Update all dependencies to latest versions"
task :update do
  sh "bundle update"
end

desc "Update dependencies and show outdated gems"
task :outdated do
  sh "bundle outdated"
end

desc "Run tests"
task :test => :spec

desc "Build the gem"
task :build do
  sh "gem build sevk.gemspec"
end

desc "Install the gem locally"
task :install => :build do
  sh "gem install sevk-*.gem"
end

desc "Release the gem to RubyGems"
task :release => :build do
  sh "gem push sevk-*.gem"
end

desc "Clean up build artifacts"
task :clean do
  FileUtils.rm_f Dir.glob("sevk-*.gem")
  FileUtils.rm_rf "pkg"
end

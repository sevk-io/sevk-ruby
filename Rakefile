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

desc "Clean up build artifacts"
task :clean do
  FileUtils.rm_f Dir.glob("sevk-*.gem")
  FileUtils.rm_rf "pkg"
end

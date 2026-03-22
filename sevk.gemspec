# frozen_string_literal: true

require_relative "lib/sevk/version"

Gem::Specification.new do |spec|
  spec.name          = "sevk"
  spec.version       = Sevk::VERSION
  spec.authors       = ["Sevk"]
  spec.email         = ["dev@sevk.io"]

  spec.summary       = "Ruby SDK for Sevk API"
  spec.description   = "Ruby SDK for interacting with the Sevk API. Send emails, manage contacts, audiences, templates, and more."
  spec.homepage      = "https://sevk.io"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sevk-io/sevk-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/sevk-io/sevk-ruby/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "nokogiri", "~> 1.15"
  spec.add_dependency "rouge", "~> 4.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end

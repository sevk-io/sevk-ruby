# frozen_string_literal: true

require_relative 'lib/sevk/version'

Gem::Specification.new do |spec|
  spec.name          = 'sevk'
  spec.version       = Sevk::VERSION
  spec.authors       = ['Sevk']
  spec.email         = ['dev@sevk.io']

  spec.summary       = 'Ruby SDK for Sevk API'
  spec.description   = 'Ruby SDK for interacting with the Sevk API. ' \
                       'Send emails, manage contacts, audiences, templates, and more.'
  spec.homepage      = 'https://sevk.io'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/sevk-io/sevk-ruby'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir['lib/**/*', 'LICENSE', 'README.md'].select { |path| File.file?(path) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'base64', '~> 0.2'
  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'rouge', '~> 4.0'
end

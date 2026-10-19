# frozen_string_literal: true

require 'faraday'
require 'json'

require_relative 'sevk/version'
require_relative 'sevk/error'
require_relative 'sevk/client'
require_relative 'sevk/resources/base'
require_relative 'sevk/resources/contacts'
require_relative 'sevk/resources/audiences'
require_relative 'sevk/resources/templates'
require_relative 'sevk/resources/broadcasts'
require_relative 'sevk/resources/domains'
require_relative 'sevk/resources/topics'
require_relative 'sevk/resources/segments'
require_relative 'sevk/resources/subscriptions'
require_relative 'sevk/resources/emails'
require_relative 'sevk/resources/webhooks'
require_relative 'sevk/resources/activity'
require_relative 'sevk/resources/inbound'
require_relative 'sevk/resources/outbound'
require_relative 'sevk/resources/usage'
require_relative 'sevk/webhook_verifier'
require_relative 'sevk/markup/renderer'

module Sevk
  DEFAULT_BASE_URL = 'https://api.sevk.io'

  class << self
    attr_accessor :api_key, :base_url

    def configure
      yield self
    end

    def client
      @client ||= Client.new(api_key: api_key, base_url: base_url)
    end

    def reset_client!
      @client = nil
    end
  end
end

# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

require_relative "sevk/version"
require_relative "sevk/error"
require_relative "sevk/client"
require_relative "sevk/resources/base"
require_relative "sevk/resources/contacts"
require_relative "sevk/resources/audiences"
require_relative "sevk/resources/templates"
require_relative "sevk/resources/broadcasts"
require_relative "sevk/resources/domains"
require_relative "sevk/resources/topics"
require_relative "sevk/resources/segments"
require_relative "sevk/resources/subscriptions"
require_relative "sevk/resources/emails"
require_relative "sevk/markup/renderer"

module Sevk
  DEFAULT_BASE_URL = "https://api.sevk.io"

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

  # Class-based API
  module Contacts
    class << self
      def list(params = {})
        Sevk.client.contacts.list(**params)
      end

      def get(id)
        Sevk.client.contacts.get(id)
      end

      def create(params)
        Sevk.client.contacts.create(**params)
      end

      def update(id, params)
        Sevk.client.contacts.update(id, **params)
      end

      def delete(id)
        Sevk.client.contacts.delete(id)
      end
    end
  end

  module Audiences
    class << self
      def list(params = {})
        Sevk.client.audiences.list(**params)
      end

      def get(id)
        Sevk.client.audiences.get(id)
      end

      def create(params)
        Sevk.client.audiences.create(**params)
      end

      def update(id, params)
        Sevk.client.audiences.update(id, **params)
      end

      def delete(id)
        Sevk.client.audiences.delete(id)
      end

      def add_contacts(id, contact_ids)
        Sevk.client.audiences.add_contacts(id, contact_ids)
      end
    end
  end

  module Templates
    class << self
      def list(params = {})
        Sevk.client.templates.list(**params)
      end

      def get(id)
        Sevk.client.templates.get(id)
      end

      def create(params)
        Sevk.client.templates.create(**params)
      end

      def update(id, params)
        Sevk.client.templates.update(id, **params)
      end

      def delete(id)
        Sevk.client.templates.delete(id)
      end

      def duplicate(id)
        Sevk.client.templates.duplicate(id)
      end
    end
  end

  module Broadcasts
    class << self
      def list(params = {})
        Sevk.client.broadcasts.list(**params)
      end

      def get(id)
        Sevk.client.broadcasts.get(id)
      end
    end
  end

  module Domains
    class << self
      def list(params = {})
        Sevk.client.domains.list(**params)
      end

      def get(id)
        Sevk.client.domains.get(id)
      end
    end
  end

  module Topics
    class << self
      def list(audience_id, params = {})
        Sevk.client.topics.list(audience_id, **params)
      end

      def get(audience_id, topic_id)
        Sevk.client.topics.get(audience_id, topic_id)
      end

      def create(audience_id, params)
        Sevk.client.topics.create(audience_id, **params)
      end

      def update(audience_id, topic_id, params)
        Sevk.client.topics.update(audience_id, topic_id, **params)
      end

      def delete(audience_id, topic_id)
        Sevk.client.topics.delete(audience_id, topic_id)
      end
    end
  end

  module Segments
    class << self
      def list(audience_id, params = {})
        Sevk.client.segments.list(audience_id, **params)
      end

      def get(audience_id, segment_id)
        Sevk.client.segments.get(audience_id, segment_id)
      end

      def create(audience_id, params)
        Sevk.client.segments.create(audience_id, **params)
      end

      def update(audience_id, segment_id, params)
        Sevk.client.segments.update(audience_id, segment_id, **params)
      end

      def delete(audience_id, segment_id)
        Sevk.client.segments.delete(audience_id, segment_id)
      end
    end
  end

  module Subscriptions
    class << self
      def subscribe(params)
        Sevk.client.subscriptions.subscribe(**params)
      end

      def unsubscribe(params)
        Sevk.client.subscriptions.unsubscribe(**params)
      end
    end
  end

  module Emails
    class << self
      def send(params)
        Sevk.client.emails.send(**params)
      end
    end
  end
end

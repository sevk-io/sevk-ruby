# frozen_string_literal: true

require 'uri'

module Sevk
  module Resources
    class Base
      attr_reader :client

      def initialize(client)
        @client = client
      end

      private

      def build_query_string(params)
        return '' if params.nil? || params.empty?

        compacted = wire_keys(params).compact
        return '' if compacted.empty?

        "?#{URI.encode_www_form(compacted)}"
      end

      def wire_keys(params)
        params.transform_keys { |key| wire_key(key) }
      end

      def wire_key(key)
        key.to_s.gsub(/_([a-z0-9])/) { Regexp.last_match(1).upcase }.to_sym
      end
    end
  end
end

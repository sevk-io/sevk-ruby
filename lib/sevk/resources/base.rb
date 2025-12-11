# frozen_string_literal: true

module Sevk
  module Resources
    class Base
      attr_reader :client

      def initialize(client)
        @client = client
      end

      private

      def build_query_string(params)
        return "" if params.nil? || params.empty?

        query = params.compact.map { |k, v| "#{k}=#{v}" }.join("&")
        query.empty? ? "" : "?#{query}"
      end
    end
  end
end

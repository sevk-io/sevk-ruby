# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Webhooks < Base
      def rotate(id)
        client.post("/webhooks/#{id}/rotate", {})
      end

      # Lists configured webhooks and the available event catalog.
      def list(page: nil, limit: nil, after: nil, before: nil)
        params = { page: page, limit: limit, after: after, before: before }

        client.get("/webhooks#{build_query_string(params)}")
      end

      # Retrieves a webhook and its recent delivery state. Its secret is the
      # masked placeholder (••••••••), not a usable verification secret.
      def get(id)
        client.get("/webhooks/#{id}")
      end

      # Creates a webhook subscription. The returned Hash always contains a non-nil
      # :secret/"secret" value prefixed with whsec_; this usable secret appears only once.
      def create(params)
        client.post('/webhooks', wire_keys(params))
      end

      # Updates a webhook while preserving omitted fields.
      def update(id, params)
        client.put("/webhooks/#{id}", wire_keys(params))
      end

      # Deletes a webhook and stops future deliveries to its URL.
      def delete(id)
        client.delete("/webhooks/#{id}")
      end

      # Sends a test event to a webhook and returns the delivery result.
      def test(id)
        client.post("/webhooks/#{id}/test", {})
      end

      # Lists event names that can be assigned to a webhook.
      def events
        client.get('/webhooks/events')
      end
    end
  end
end

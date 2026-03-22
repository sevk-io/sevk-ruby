# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Webhooks < Base
      def list(page: nil, limit: nil)
        params = { page: page, limit: limit }
        client.get("/webhooks#{build_query_string(params)}")
      end

      def get(id)
        client.get("/webhooks/#{id}")
      end

      def create(params)
        client.post("/webhooks", params)
      end

      def update(id, params)
        client.put("/webhooks/#{id}", params)
      end

      def delete(id)
        client.delete("/webhooks/#{id}")
      end

      def test(id)
        client.post("/webhooks/#{id}/test", {})
      end

      def list_events
        client.get("/webhooks/events")
      end
    end
  end
end

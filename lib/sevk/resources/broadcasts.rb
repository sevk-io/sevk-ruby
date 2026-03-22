# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Broadcasts < Base
      def list(page: nil, limit: nil, search: nil, status: nil)
        params = { page: page, limit: limit, search: search, status: status }
        client.get("/broadcasts#{build_query_string(params)}")
      end

      def get(id)
        client.get("/broadcasts/#{id}")
      end

      def create(params)
        client.post("/broadcasts", params)
      end

      def update(id, params)
        client.put("/broadcasts/#{id}", params)
      end

      def delete(id)
        client.delete("/broadcasts/#{id}")
      end

      def send(id)
        client.post("/broadcasts/#{id}/send")
      end

      def cancel(id)
        client.post("/broadcasts/#{id}/cancel")
      end

      def send_test(id, params)
        client.post("/broadcasts/#{id}/test", params)
      end

      def get_analytics(id)
        client.get("/broadcasts/#{id}/analytics")
      end

      def get_status(id)
        client.get("/broadcasts/#{id}/status")
      end

      def get_emails(id, params = {})
        client.get("/broadcasts/#{id}/emails#{build_query_string(params)}")
      end

      def estimate_cost(id)
        client.get("/broadcasts/#{id}/estimate-cost")
      end

      def list_active
        client.get("/broadcasts/active")
      end
    end
  end
end

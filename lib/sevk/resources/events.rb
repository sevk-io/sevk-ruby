# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Events < Base
      def list(page: nil, limit: nil, type: nil, contact_id: nil)
        params = { page: page, limit: limit, type: type, contact_id: contact_id }
        client.get("/events#{build_query_string(params)}")
      end

      def stats
        client.get("/events/stats")
      end
    end
  end
end

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
    end
  end
end

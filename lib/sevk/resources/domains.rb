# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Domains < Base
      def list(verified: nil)
        params = { verified: verified }
        client.get("/domains#{build_query_string(params)}")
      end

      def get(id)
        client.get("/domains/#{id}")
      end
    end
  end
end

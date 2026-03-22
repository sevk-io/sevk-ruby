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

      def create(params)
        client.post("/domains", params)
      end

      def update(id, params)
        client.put("/domains/#{id}", params)
      end

      def delete(id)
        client.delete("/domains/#{id}")
      end

      def verify(id)
        client.post("/domains/#{id}/verify", {})
      end

      def get_dns_records(id)
        client.get("/domains/#{id}/dns-records")
      end

      def get_regions
        client.get("/domains/regions")
      end
    end
  end
end

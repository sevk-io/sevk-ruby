# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Segments < Base
      def list(audience_id, page: nil, limit: nil)
        params = { page: page, limit: limit }
        client.get("/audiences/#{audience_id}/segments#{build_query_string(params)}")
      end

      def get(audience_id, segment_id)
        client.get("/audiences/#{audience_id}/segments/#{segment_id}")
      end

      def create(audience_id, name:, rules:, operator: "AND")
        body = { name: name, rules: rules, operator: operator }
        client.post("/audiences/#{audience_id}/segments", body)
      end

      def update(audience_id, segment_id, name: nil, rules: nil, operator: nil)
        body = {}
        body[:name] = name if name
        body[:rules] = rules if rules
        body[:operator] = operator if operator
        client.put("/audiences/#{audience_id}/segments/#{segment_id}", body)
      end

      def delete(audience_id, segment_id)
        client.delete("/audiences/#{audience_id}/segments/#{segment_id}")
      end

      def calculate(audience_id, segment_id)
        client.get("/audiences/#{audience_id}/segments/#{segment_id}/calculate")
      end

      def preview(audience_id, data)
        client.post("/audiences/#{audience_id}/segments/preview", data)
      end
    end
  end
end

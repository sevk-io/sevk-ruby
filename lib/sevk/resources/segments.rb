# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Segments < Base
      # Lists segments belonging to an audience with optional filtering.
      def list(audience_id, page: nil, limit: nil, after: nil, before: nil, search: nil)
        params = { page: page, limit: limit, after: after, before: before, search: search }

        client.get("/audiences/#{audience_id}/segments#{build_query_string(params)}")
      end

      # Creates a saved contact segment under an audience.
      def create(audience_id, name:, rules:, operator: 'AND', limit_to_topics: nil, groups: nil)
        body = { name: name, rules: rules, operator: operator }
        body[:limitToTopics] = limit_to_topics unless limit_to_topics.nil?
        body[:groups] = groups unless groups.nil?

        client.post("/audiences/#{audience_id}/segments", body)
      end

      # Evaluates segment rules and returns matches without saving a segment.
      def preview(audience_id, data)
        client.post("/audiences/#{audience_id}/segments/preview", wire_keys(data))
      end

      # Retrieves a saved segment by id.
      def get(segment_id)
        client.get("/segments/#{segment_id}")
      end

      # Updates a segment while preserving omitted fields.
      def update(segment_id, name: nil, rules: nil, operator: nil, limit_to_topics: nil, groups: nil)
        body = {}
        body[:name] = name unless name.nil?
        body[:rules] = rules unless rules.nil?
        body[:operator] = operator unless operator.nil?
        body[:limitToTopics] = limit_to_topics unless limit_to_topics.nil?
        body[:groups] = groups unless groups.nil?

        client.put("/segments/#{segment_id}", body)
      end

      # Deletes a segment without deleting any contacts.
      def delete(segment_id)
        client.delete("/segments/#{segment_id}")
      end

      # Recalculates and returns the current matching contact count.
      def calculate(segment_id)
        client.get("/segments/#{segment_id}/calculate")
      end
    end
  end
end

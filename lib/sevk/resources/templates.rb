# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Templates < Base
      def list(page: nil, limit: nil, search: nil)
        params = { page: page, limit: limit, search: search }
        client.get("/templates#{build_query_string(params)}")
      end

      def get(id)
        client.get("/templates/#{id}")
      end

      def create(title:, content:)
        client.post("/templates", { title: title, content: content })
      end

      def update(id, title: nil, content: nil)
        body = {}
        body[:title] = title if title
        body[:content] = content if content
        client.put("/templates/#{id}", body)
      end

      def delete(id)
        client.delete("/templates/#{id}")
      end

      def duplicate(id)
        client.post("/templates/#{id}/duplicate", {})
      end
    end
  end
end

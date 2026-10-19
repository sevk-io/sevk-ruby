# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Templates < Base
      # Lists reusable email templates with optional pagination and search.
      def list(page: nil, limit: nil, after: nil, before: nil, search: nil)
        params = { page: page, limit: limit, after: after, before: before, search: search }

        client.get("/templates#{build_query_string(params)}")
      end

      # Retrieves a template by id.
      def get(id)
        client.get("/templates/#{id}")
      end

      # Creates a reusable email template from markup and optional styles.
      def create(title:, content:, style: nil)
        body = { title: title, content: content }
        body[:style] = style unless style.nil?

        client.post('/templates', body)
      end

      # Updates a template while preserving omitted fields.
      def update(id, title: nil, content: nil, style: nil)
        body = {}
        body[:title] = title unless title.nil?
        body[:content] = content unless content.nil?
        body[:style] = style unless style.nil?

        client.put("/templates/#{id}", body)
      end

      # Deletes a template without affecting email already sent from it.
      def delete(id)
        client.delete("/templates/#{id}")
      end

      # Creates an independent copy of a template for further editing.
      def duplicate(id)
        client.post("/templates/#{id}/duplicate", {})
      end
    end
  end
end

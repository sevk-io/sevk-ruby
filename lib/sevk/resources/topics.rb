# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Topics < Base
      def list(audience_id, page: nil, limit: nil)
        params = { page: page, limit: limit }
        client.get("/audiences/#{audience_id}/topics#{build_query_string(params)}")
      end

      def get(audience_id, topic_id)
        client.get("/audiences/#{audience_id}/topics/#{topic_id}")
      end

      def create(audience_id, name:, description: nil)
        body = { name: name }
        body[:description] = description if description
        client.post("/audiences/#{audience_id}/topics", body)
      end

      def update(audience_id, topic_id, name: nil, description: nil)
        body = {}
        body[:name] = name if name
        body[:description] = description if description
        client.put("/audiences/#{audience_id}/topics/#{topic_id}", body)
      end

      def delete(audience_id, topic_id)
        client.delete("/audiences/#{audience_id}/topics/#{topic_id}")
      end

      def add_contacts(audience_id, topic_id, contact_ids:)
        client.post("/audiences/#{audience_id}/topics/#{topic_id}/contacts", { contactIds: contact_ids })
      end

      def remove_contact(audience_id, topic_id, contact_id)
        client.delete("/audiences/#{audience_id}/topics/#{topic_id}/contacts/#{contact_id}")
      end

      def list_contacts(audience_id, topic_id, params = {})
        client.get("/audiences/#{audience_id}/topics/#{topic_id}/contacts#{build_query_string(params)}")
      end
    end
  end
end

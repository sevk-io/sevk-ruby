# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Topics < Base
      # Lists topics belonging to an audience with optional filtering.
      def list(audience_id, page: nil, limit: nil, after: nil, before: nil, search: nil)
        params = { page: page, limit: limit, after: after, before: before, search: search }

        client.get("/audiences/#{audience_id}/topics#{build_query_string(params)}")
      end

      # Creates a subscription topic under an audience.
      def create(audience_id, name:, description: nil)
        body = { name: name }
        body[:description] = description unless description.nil?

        client.post("/audiences/#{audience_id}/topics", body)
      end

      # Retrieves a topic by id.
      def get(topic_id)
        client.get("/topics/#{topic_id}")
      end

      # Updates a topic while preserving omitted fields.
      def update(topic_id, name: nil, description: nil)
        body = {}
        body[:name] = name unless name.nil?
        body[:description] = description unless description.nil?

        client.put("/topics/#{topic_id}", body)
      end

      # Deletes a topic without deleting its contacts or parent audience.
      def delete(topic_id)
        client.delete("/topics/#{topic_id}")
      end

      # Adds contacts to a topic, ignoring memberships that already exist.
      def add_contacts(topic_id, contact_ids:)
        client.post("/topics/#{topic_id}/contacts", { contactIds: contact_ids })
      end

      # Removes a contact from the topic without deleting the contact.
      def remove_contact(topic_id, contact_id)
        client.delete("/topics/#{topic_id}/contacts/#{contact_id}")
      end

      # Lists contacts by page, cursor, search text, or subscription state.
      def list_contacts(topic_id, params = {})
        client.get("/topics/#{topic_id}/contacts#{build_query_string(params)}")
      end
    end
  end
end

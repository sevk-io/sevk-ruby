# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Audiences < Base
      # Lists audiences with optional pagination and search.
      def list(page: nil, limit: nil, after: nil, before: nil, search: nil)
        params = { page: page, limit: limit, after: after, before: before, search: search }

        client.get("/audiences#{build_query_string(params)}")
      end

      # Retrieves an audience by id.
      def get(id)
        client.get("/audiences/#{id}")
      end

      # Creates an audience for organizing contacts, topics, and segments.
      def create(name:, description: nil, visibility: nil)
        body = { name: name }
        body[:description] = description unless description.nil?
        body[:visibility] = visibility unless visibility.nil?

        client.post('/audiences', body)
      end

      # Updates an audience while preserving omitted fields.
      def update(id, name: nil, description: nil, visibility: nil)
        body = {}
        body[:name] = name unless name.nil?
        body[:description] = description unless description.nil?
        body[:visibility] = visibility unless visibility.nil?

        client.put("/audiences/#{id}", body)
      end

      # Deletes an audience without deleting its contacts.
      def delete(id)
        client.delete("/audiences/#{id}")
      end

      # Adds contacts to an audience, ignoring memberships that already exist.
      def add_contacts(audience_id, contact_ids)
        client.post("/audiences/#{audience_id}/contacts", { contactIds: contact_ids })
      end

      # Lists contacts attached to an audience with optional filtering.
      def list_contacts(audience_id, params = {})
        client.get("/audiences/#{audience_id}/contacts#{build_query_string(params)}")
      end

      # Removes a contact from the audience without deleting the contact.
      def remove_contact(audience_id, contact_id)
        client.delete("/audiences/#{audience_id}/contacts/#{contact_id}")
      end
    end
  end
end

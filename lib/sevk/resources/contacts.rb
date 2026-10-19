# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Contacts < Base
      UNSET = Object.new
      private_constant :UNSET

      # Lists contacts with optional pagination, search, and subscription filters.
      def list(page: nil, limit: nil, after: nil, before: nil, search: nil, exclude_audience: nil, subscribed: nil)
        params = { page: page, limit: limit, after: after, before: before, search: search,
                   excludeAudience: exclude_audience }
        params[:subscribed] = subscribed unless subscribed.nil?

        client.get("/contacts#{build_query_string(params)}")
      end

      # Retrieves a contact by id.
      def get(id)
        client.get("/contacts/#{id}")
      end

      # Creates a contact and optionally attaches custom metadata.
      def create(email:, subscribed: nil, data: nil)
        body = { email: email }
        body[:subscribed] = subscribed unless subscribed.nil?
        body[:data] = data unless data.nil?

        client.post('/contacts', body)
      end

      # Updates a contact. Explicit nil clears metadata; omitted data preserves it.
      def update(id, email: nil, subscribed: nil, data: UNSET)
        body = {}
        body[:email] = email unless email.nil?
        body[:subscribed] = subscribed unless subscribed.nil?
        body[:data] = data unless data.equal?(UNSET)

        client.put("/contacts/#{id}", body)
      end

      # Deletes a contact and removes its audience and topic memberships.
      def delete(id)
        client.delete("/contacts/#{id}")
      end

      # Updates multiple contacts by email and reports entries that were not found.
      def bulk_update(updates)
        client.put('/contacts/bulk-update', updates)
      end

      # Imports contacts in one request, optionally attaching them to a group.
      def bulk_import(params)
        client.post('/contacts/import', wire_keys(params))
      end

      # Lists delivery and engagement activity for a contact.
      def activity(id, page: nil, limit: nil, after: nil, before: nil)
        params = { page: page, limit: limit, after: after, before: before }

        client.get("/contacts/#{id}/activity#{build_query_string(params)}")
      end
    end
  end
end

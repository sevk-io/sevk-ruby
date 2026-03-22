# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Contacts < Base
      def list(page: nil, limit: nil, search: nil)
        params = { page: page, limit: limit, search: search }
        client.get("/contacts#{build_query_string(params)}")
      end

      def get(id)
        client.get("/contacts/#{id}")
      end

      def create(email:, first_name: nil, last_name: nil, subscribed: nil, metadata: nil)
        body = { email: email }
        body[:firstName] = first_name if first_name
        body[:lastName] = last_name if last_name
        body[:subscribed] = subscribed unless subscribed.nil?
        body[:metadata] = metadata if metadata
        client.post("/contacts", body)
      end

      def update(id, first_name: nil, last_name: nil, subscribed: nil, metadata: nil)
        body = {}
        body[:firstName] = first_name if first_name
        body[:lastName] = last_name if last_name
        body[:subscribed] = subscribed unless subscribed.nil?
        body[:metadata] = metadata if metadata
        client.put("/contacts/#{id}", body)
      end

      def delete(id)
        client.delete("/contacts/#{id}")
      end

      def bulk_update(updates)
        client.put("/contacts/bulk-update", updates)
      end

      def import_csv(params)
        client.post("/contacts/import", params)
      end

      def get_events(id)
        client.get("/contacts/#{id}/events")
      end
    end
  end
end

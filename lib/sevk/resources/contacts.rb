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
    end
  end
end

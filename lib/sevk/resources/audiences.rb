# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Audiences < Base
      def list(page: nil, limit: nil)
        params = { page: page, limit: limit }
        client.get("/audiences#{build_query_string(params)}")
      end

      def get(id)
        client.get("/audiences/#{id}")
      end

      def create(name:, description: nil, users_can_see: nil)
        body = { name: name }
        body[:description] = description if description
        body[:usersCanSee] = users_can_see if users_can_see
        client.post("/audiences", body)
      end

      def update(id, name: nil, description: nil, users_can_see: nil)
        body = {}
        body[:name] = name if name
        body[:description] = description if description
        body[:usersCanSee] = users_can_see if users_can_see
        client.put("/audiences/#{id}", body)
      end

      def delete(id)
        client.delete("/audiences/#{id}")
      end

      def add_contacts(audience_id, contact_ids)
        client.post("/audiences/#{audience_id}/contacts", { contactIds: contact_ids })
      end
    end
  end
end

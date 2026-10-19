# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Inbound < Base
      # Lists received email with optional pagination and filtering.
      def list(page: nil, limit: nil, after: nil, before: nil, search: nil, status: nil, domain_id: nil,
               broadcast_id: nil, is_spam: nil, is_virus: nil)
        params = {
          page: page,
          limit: limit,
          after: after,
          before: before,
          search: search,
          status: status,
          domainId: domain_id,
          broadcastId: broadcast_id,
          isSpam: is_spam,
          isVirus: is_virus
        }

        client.get("/inbound#{build_query_string(params)}")
      end

      # Retrieves a received email with parsed content and attachment metadata.
      def get(id)
        client.get("/inbound/#{id}")
      end

      # Deletes a received email and its stored content.
      def delete(id)
        client.delete("/inbound/#{id}")
      end

      # Returns aggregate inbound processing statistics, optionally for one domain.
      def stats(domain_id: nil)
        params = { domainId: domain_id }

        client.get("/inbound/stats#{build_query_string(params)}")
      end

      # Downloads the original content and metadata for an inbound attachment.
      def download_attachment(email_id, attachment_id)
        client.get("/inbound/#{email_id}/attachments/#{attachment_id}/download")
      end

      # Lists rules used to store or forward matching inbound email.
      def list_routes(**params)
        client.get("/inbound-settings/routes#{build_query_string(params)}")
      end

      def route_items(**params)
        list_routes(**params).fetch('items')
      end

      # Retrieves an inbound routing rule by id.
      def get_route(id)
        client.get("/inbound-settings/routes/#{id}")
      end

      # Creates an inbound routing rule.
      def create_route(**params)
        client.post('/inbound-settings/routes', wire_keys(params))
      end

      # Updates an inbound routing rule while preserving omitted fields.
      def update_route(id, **params)
        client.put("/inbound-settings/routes/#{id}", wire_keys(params))
      end

      # Deletes an inbound routing rule without deleting stored email.
      def delete_route(id)
        client.delete("/inbound-settings/routes/#{id}")
      end

      # Lists blocked addresses with optional offset or cursor pagination.
      def list_blocklist(**params)
        client.get("/inbound-settings/blocklist#{build_query_string(params)}")
      end

      def blocklist_items(**params)
        list_blocklist(**params).fetch('items')
      end

      # Adds an address to the inbound blocklist.
      def add_blocklist_entry(**params)
        client.post('/inbound-settings/blocklist', wire_keys(params))
      end

      # Removes an address from the inbound blocklist.
      def remove_blocklist_entry(id)
        client.delete("/inbound-settings/blocklist/#{id}")
      end

      # Returns inbound quota settings and current usage counters.
      def get_quota
        client.get('/inbound-settings/quota')
      end

      # Updates the inbound monthly limit while preserving omitted fields.
      def update_quota(**params)
        client.put('/inbound-settings/quota', wire_keys(params))
      end

      # Clears a quota pause without resetting current-period usage.
      def reset_quota
        client.post('/inbound-settings/quota/reset', {})
      end

      # Returns effective inbound security settings for a domain.
      def get_security_config(domain_id)
        client.get("/inbound-settings/security/#{domain_id}")
      end

      # Updates inbound security settings for a domain.
      def update_security_config(domain_id, **params)
        client.put("/inbound-settings/security/#{domain_id}", wire_keys(params))
      end
    end
  end
end

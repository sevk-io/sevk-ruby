# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Domains < Base
      # Lists sending domains, optionally filtered by verification state.
      def list(verified: nil, page: nil, limit: nil, after: nil, before: nil)
        params = { verified: verified, page: page, limit: limit, after: after, before: before }

        client.get("/domains#{build_query_string(params)}")
      end

      # Retrieves a domain and its current verification state.
      def get(id)
        client.get("/domains/#{id}")
      end

      # registers an exact domain claim; dns fields depend on domain:dns-read.
      def create(params)
        client.post('/domains', wire_keys(params))
      end

      # Updates sending, tracking, TLS, or inbound settings for a domain.
      def update(id, params)
        client.put("/domains/#{id}", wire_keys(params))
      end

      # Deletes a domain after the API confirms it is safe to remove.
      def delete(id)
        client.delete("/domains/#{id}")
      end

      # Rechecks sending DNS records and returns the updated domain state.
      def verify(id)
        client.post("/domains/#{id}/verify", {})
      end

      # Checks the inbound MX record and returns details useful for DNS diagnosis.
      def verify_inbound(id)
        client.post("/domains/#{id}/inbound/verify", {})
      end

      # Returns the DNS records required for sending and inbound mail.
      def dns_records(id)
        client.get("/domains/#{id}/dns-records")
      end

      # Lists region identifiers accepted when registering a domain.
      def regions
        client.get('/domains/regions')
      end
    end
  end
end

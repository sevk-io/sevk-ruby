# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Broadcasts < Base
      # Lists broadcasts with optional pagination, search, and status filtering.
      def list(page: nil, limit: nil, after: nil, before: nil, search: nil, status: nil)
        params = { page: page, limit: limit, after: after, before: before, search: search, status: status }

        client.get("/broadcasts#{build_query_string(params)}")
      end

      # Retrieves a broadcast by id and includes its current delivery state.
      def get(id)
        client.get("/broadcasts/#{id}")
      end

      # Creates a draft or scheduled broadcast for a target group.
      def create(params)
        client.post('/broadcasts', broadcast_body(params))
      end

      # Updates a broadcast while preserving omitted fields. The response includes
      # variants and abTest when this mutation touched experiment state.
      def update(id, params)
        client.put("/broadcasts/#{id}", broadcast_body(params))
      end

      # Deletes a broadcast that has not been sent.
      def delete(id)
        client.delete("/broadcasts/#{id}")
      end

      # Queues a prepared broadcast for delivery.
      def send(id)
        client.post("/broadcasts/#{id}/send")
      end

      # Cancels a broadcast when its state still allows cancellation.
      def cancel(id)
        client.post("/broadcasts/#{id}/cancel")
      end

      # Sends the broadcast to test recipients without starting the campaign.
      def test(id, params, options: nil)
        client.post("/broadcasts/#{id}/test", wire_keys(params), headers: idempotency_headers(options))
      end

      # Returns aggregate delivery and engagement analytics for a broadcast.
      def analytics(id)
        client.get("/broadcasts/#{id}/analytics")
      end

      # Returns live scheduling and delivery progress for a broadcast.
      def status(id)
        client.get("/broadcasts/#{id}/status")
      end

      # Lists email deliveries created for a broadcast.
      def emails(id, params = {})
        client.get("/broadcasts/#{id}/emails#{build_query_string(params)}")
      end

      # Estimates delivery cost without sending the broadcast.
      def estimate_cost(id)
        client.get("/broadcasts/#{id}/estimate-cost")
      end

      # Resolves the subscribed recipient count for a broadcast target.
      def estimate_recipients(params)
        client.post('/broadcasts/estimate-recipients', wire_keys(params))
      end

      # Lists broadcasts that are currently scheduled or processing.
      def active
        client.get('/broadcasts/active')
      end

      private

      def broadcast_body(params)
        body = wire_keys(params)

        if body[:variants].is_a?(Array)
          body[:variants] = body[:variants].map { |variant| variant.is_a?(Hash) ? wire_keys(variant) : variant }
        end

        body[:abTest] = wire_keys(body[:abTest]) if body[:abTest].is_a?(Hash)

        body
      end

      def idempotency_headers(options)
        return nil unless options

        return nil unless options.key?(:idempotency_key) || options.key?('idempotency_key')

        key = options.key?(:idempotency_key) ? options[:idempotency_key] : options['idempotency_key']

        { 'Idempotency-Key' => key.to_s }
      end
    end
  end
end

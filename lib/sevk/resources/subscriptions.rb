# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Subscriptions < Base
      # Subscribes a contact and optionally adds it to an audience.
      def subscribe(email:, audience_id: nil, data: nil)
        body = { email: email }
        body[:audienceId] = audience_id unless audience_id.nil?
        body[:data] = data unless data.nil?

        client.post('/subscriptions/subscribe', body)
      end

      # Global opt-out. Provide at least one of email or contact_id (if both are
      # given, contact_id wins). broadcast_id only attributes the opt-out to a
      # broadcast (activity + counters); it does NOT scope the unsubscribe.
      def unsubscribe(email: nil, contact_id: nil, broadcast_id: nil)
        body = {}
        body[:email] = email unless email.nil?
        body[:contactId] = contact_id unless contact_id.nil?
        body[:broadcastId] = broadcast_id unless broadcast_id.nil?

        client.post('/subscriptions/unsubscribe', body)
      end
    end
  end
end

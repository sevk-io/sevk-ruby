# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Subscriptions < Base
      def subscribe(email:, audience_id:, topic_ids: nil, metadata: nil)
        body = { email: email, audienceId: audience_id }
        body[:topicIds] = topic_ids if topic_ids
        body[:metadata] = metadata if metadata
        client.post("/subscriptions/subscribe", body)
      end

      def unsubscribe(email:, audience_id: nil, topic_ids: nil)
        body = { email: email }
        body[:audienceId] = audience_id if audience_id
        body[:topicIds] = topic_ids if topic_ids
        client.post("/subscriptions/unsubscribe", body)
      end
    end
  end
end

# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Emails < Base
      def send(to:, subject:, html:, from:, from_name: nil, reply_to: nil, text: nil, headers: nil, tags: nil)
        body = {
          to: to,
          subject: subject,
          html: html,
          from: from
        }
        body[:fromName] = from_name if from_name
        body[:replyTo] = reply_to if reply_to
        body[:text] = text if text
        body[:headers] = headers if headers
        body[:tags] = tags if tags
        client.post("emails", body)
      end
    end
  end
end

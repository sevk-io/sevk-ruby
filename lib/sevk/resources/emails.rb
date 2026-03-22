# frozen_string_literal: true

require_relative "base"

module Sevk
  module Resources
    class Emails < Base
      # Send an email with optional attachments
      #
      # @param to [String, Array<String>] Recipient email(s)
      # @param subject [String] Email subject
      # @param html [String] HTML content
      # @param from [String] Sender email
      # @param from_name [String, nil] Sender name
      # @param reply_to [String, nil] Reply-to address
      # @param text [String, nil] Plain text content
      # @param headers [Hash, nil] Custom headers
      # @param tags [Array, nil] Tags
      # @param attachments [Array<Hash>, nil] Attachments (max 10, 10MB total)
      #   Each attachment: { filename: String, content: String (base64), content_type: String }
      # @return [Hash] Response with :id or :ids
      def send(to:, subject:, html:, from:, from_name: nil, reply_to: nil, text: nil, headers: nil, tags: nil, attachments: nil)
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
        body[:attachments] = attachments if attachments
        client.post("emails", body)
      end

      # Send multiple emails in bulk
      #
      # @param emails [Array<Hash>] Array of email parameter hashes (max 100)
      # @return [Hash] Response with :success, :failed, :ids, :errors
      def send_bulk(emails)
        client.post("emails/bulk", { emails: emails })
      end

      # Get an email by ID
      #
      # @param id [String] Email ID
      # @return [Hash] Email details
      def get(id)
        client.get("/emails/#{id}")
      end
    end
  end
end

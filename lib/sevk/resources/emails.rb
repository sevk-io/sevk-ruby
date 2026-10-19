# frozen_string_literal: true

require_relative 'base'
require_relative '../markup/renderer'

module Sevk
  module Resources
    class Emails < Base
      # Sends one transactional email, rendering local markup when supplied.
      def send(to:, subject:, from:, html: nil, text: nil, markup: nil, reply_to: nil, cc: nil, bcc: nil,
               attachments: nil, tracking: nil, headers: nil, scheduled_at: nil, options: nil)
        body = {
          to: to,
          subject: subject,
          from: from
        }
        body[:html] = html unless html.nil?
        body[:html] = Sevk::Markup::Renderer.new.render(markup) if markup && !markup.empty?
        body[:text] = text unless text.nil?
        body[:reply_to] = reply_to unless reply_to.nil?
        body[:cc] = cc unless cc.nil?
        body[:bcc] = bcc unless bcc.nil?
        body[:attachments] = normalize_attachments(attachments) unless attachments.nil?
        body[:tracking] = tracking unless tracking.nil?
        body[:headers] = headers unless headers.nil?
        body[:scheduledAt] = scheduled_at unless scheduled_at.nil?

        client.post('/emails', body, headers: idempotency_headers(options))
      end

      # Sends up to 100 transactional emails and returns per-request results.
      def send_bulk(emails, options: nil)
        unless emails.is_a?(Array)
          return client.post('/emails/bulk', { emails: emails }, headers: idempotency_headers(options))
        end

        wire_emails = emails.map do |email|
          next email unless email.is_a?(Hash)

          payload = email.dup
          symbol_markup = payload.delete(:markup)
          string_markup = payload.delete('markup')
          mk = symbol_markup.nil? ? string_markup : symbol_markup
          unless mk.nil? || mk.empty?
            payload.delete(:html)
            payload.delete('html')
            payload[:html] = Sevk::Markup::Renderer.new.render(mk)
          end
          attachments = payload[:attachments] || payload['attachments']
          if attachments
            payload.delete('attachments')
            payload[:attachments] = normalize_attachments(attachments)
          end
          payload
        end

        client.post('/emails/bulk', { emails: wire_emails }, headers: idempotency_headers(options))
      end

      # Retrieves a sent email and its current delivery state.
      def get(id)
        client.get("/emails/#{id}")
      end

      # moves an unattempted scheduled email to a new delivery time.
      def update(id, scheduled_at:)
        client.patch("/emails/#{id}", { scheduledAt: scheduled_at })
      end

      # cancels an unattempted scheduled email.
      def cancel(id)
        client.post("/emails/#{id}/cancel")
      end

      private

      def normalize_attachments(attachments)
        return attachments unless attachments.is_a?(Array)

        attachments.map do |attachment|
          next attachment unless attachment.is_a?(Hash)

          normalized = attachment.dup
          content_type = normalized.delete(:content_type)
          content_type = normalized.delete('content_type') if content_type.nil?
          unless content_type.nil? || normalized.key?(:contentType) || normalized.key?('contentType')
            normalized[:contentType] = content_type
          end

          normalized
        end
      end

      # Builds the optional idempotency header used to make retries safe.
      def idempotency_headers(options)
        return nil unless options

        return nil unless options.key?(:idempotency_key) || options.key?('idempotency_key')

        key = options.key?(:idempotency_key) ? options[:idempotency_key] : options['idempotency_key']

        { 'Idempotency-Key' => key.to_s }
      end
    end
  end
end

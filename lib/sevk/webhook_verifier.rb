# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'

module Sevk
  class WebhookVerificationError < StandardError; end

  # Verifier for sevk webhook deliveries.
  #
  # sevk uses the Svix-compatible signature scheme (svix-id, svix-timestamp,
  # svix-signature headers), so this helper or the official `svix` gem can be
  # used. sevk issues canonical whsec_ base64 secrets that can be passed
  # directly to either verifier.
  class WebhookVerifier
    TOLERANCE_SECONDS = 5 * 60

    # Prepares a verifier with the signing secret issued for a webhook.
    def initialize(secret)
      raise WebhookVerificationError, 'Webhook secret is required' if secret.nil? || secret.empty?

      @key = if secret.start_with?('whsec_')
               begin
                 decoded = Base64.strict_decode64(secret[6..])
                 raise ArgumentError if decoded.empty?

                 decoded
               rescue ArgumentError
                 raise WebhookVerificationError, 'Invalid base64 secret'
               end
             else
               secret
             end
    end

    # Verifies the delivery signature and timestamp, then parses its JSON payload.
    def verify(payload, headers)
      msg_id = lookup(headers, 'svix-id')
      msg_timestamp = lookup(headers, 'svix-timestamp')
      msg_signature = lookup(headers, 'svix-signature')

      if msg_id.nil? || msg_id.empty? || msg_timestamp.nil? || msg_signature.nil?
        raise WebhookVerificationError, 'Missing required svix headers'
      end

      raise WebhookVerificationError, 'Invalid timestamp header' unless msg_timestamp.match?(/\A[0-9]+\z/)

      timestamp = Integer(msg_timestamp, 10)
      now = Time.now.to_i
      if timestamp < now - TOLERANCE_SECONDS || timestamp > now + TOLERANCE_SECONDS
        raise WebhookVerificationError, 'Timestamp outside tolerance window'
      end

      to_sign = "#{msg_id}.#{msg_timestamp}.#{payload}"
      digest = OpenSSL::HMAC.digest('SHA256', @key, to_sign)
      expected = "v1,#{Base64.strict_encode64(digest)}"

      msg_signature.split.each do |candidate|
        next unless secure_compare(expected, candidate)

        begin
          return JSON.parse(payload)
        rescue JSON::ParserError
          raise WebhookVerificationError, 'Invalid JSON payload'
        end
      end

      raise WebhookVerificationError, 'Signature mismatch'
    rescue ArgumentError
      raise WebhookVerificationError, 'Invalid timestamp header'
    end

    private

    def lookup(headers, name)
      headers.each do |key, value|
        normalized = key.to_s.downcase.tr('_', '-').sub(/\Ahttp-/, '')
        return value unless value.nil? || normalized != name
      end

      nil
    end

    def secure_compare(expected, candidate)
      return false unless expected.bytesize == candidate.bytesize

      OpenSSL.fixed_length_secure_compare(expected, candidate)
    end
  end
end

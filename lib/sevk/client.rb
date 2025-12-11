# frozen_string_literal: true

module Sevk
  class Client
    attr_reader :api_key, :base_url

    def initialize(api_key:, base_url: nil)
      @api_key = api_key
      @base_url = base_url || DEFAULT_BASE_URL
    end

    def contacts
      @contacts ||= Resources::Contacts.new(self)
    end

    def audiences
      @audiences ||= Resources::Audiences.new(self)
    end

    def templates
      @templates ||= Resources::Templates.new(self)
    end

    def broadcasts
      @broadcasts ||= Resources::Broadcasts.new(self)
    end

    def domains
      @domains ||= Resources::Domains.new(self)
    end

    def topics
      @topics ||= Resources::Topics.new(self)
    end

    def segments
      @segments ||= Resources::Segments.new(self)
    end

    def subscriptions
      @subscriptions ||= Resources::Subscriptions.new(self)
    end

    def emails
      @emails ||= Resources::Emails.new(self)
    end

    def get(path, params = {})
      request(:get, path, params)
    end

    def post(path, body = {})
      request(:post, path, body)
    end

    def patch(path, body = {})
      request(:patch, path, body)
    end

    def put(path, body = {})
      request(:put, path, body)
    end

    def delete(path)
      request(:delete, path)
    end

    private

    def connection
      @connection ||= Faraday.new do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.request :retry, max: 2, interval: 0.5, backoff_factor: 2
        conn.headers["Authorization"] = "Bearer #{api_key}"
        conn.headers["Content-Type"] = "application/json"
        conn.headers["Accept"] = "application/json"
        conn.adapter Faraday.default_adapter
      end
    end

    def build_url(path)
      # Ensure base_url ends without slash and path starts with slash
      base = base_url.chomp("/")
      path = "/#{path}" unless path.start_with?("/")
      "#{base}#{path}"
    end

    def request(method, path, body = nil)
      url = build_url(path)
      response = case method
                 when :get
                   connection.get(url, body)
                 when :post
                   connection.post(url, body)
                 when :patch
                   connection.patch(url, body)
                 when :put
                   connection.put(url, body)
                 when :delete
                   connection.delete(url)
                 end

      handle_response(response)
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 400
        raise ValidationError.new(
          error_message(response),
          status_code: response.status,
          response: response.body
        )
      when 401
        raise AuthenticationError.new(
          error_message(response),
          status_code: response.status,
          response: response.body
        )
      when 403
        raise Error.new(
          error_message(response),
          status_code: response.status,
          response: response.body
        )
      when 404
        raise NotFoundError.new(
          error_message(response),
          status_code: response.status,
          response: response.body
        )
      when 429
        raise RateLimitError.new(
          error_message(response),
          status_code: response.status,
          response: response.body
        )
      when 500..599
        raise ServerError.new(
          error_message(response),
          status_code: response.status,
          response: response.body
        )
      else
        raise Error.new(
          error_message(response),
          status_code: response.status,
          response: response.body
        )
      end
    end

    def error_message(response)
      if response.body.is_a?(Hash) && response.body["message"]
        "#{response.status}: #{response.body['message']}"
      else
        "#{response.status}: #{response.body}"
      end
    end
  end
end

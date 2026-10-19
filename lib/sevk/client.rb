# frozen_string_literal: true

module Sevk
  class Client
    attr_reader :api_key, :base_url, :timeout

    def initialize(api_key:, base_url: nil, timeout: 30)
      @api_key = api_key
      @base_url = base_url || DEFAULT_BASE_URL
      @timeout = timeout
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

    def webhooks
      @webhooks ||= Resources::Webhooks.new(self)
    end

    def activity
      @activity ||= Resources::Activity.new(self)
    end

    def inbound
      @inbound ||= Resources::Inbound.new(self)
    end

    def outbound
      @outbound ||= Resources::Outbound.new(self)
    end

    def usage
      @usage ||= Resources::Usage.new(self)
    end

    def get(path, params = {})
      request(:get, path, params)
    end

    def post(path, body = {}, headers: nil)
      request(:post, path, body, headers: headers)
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
        conn.options.timeout = timeout
        conn.options.open_timeout = timeout
        conn.headers['Authorization'] = "Bearer #{api_key}"
        conn.headers['Content-Type'] = 'application/json'
        conn.headers['Accept'] = 'application/json'
        conn.headers['User-Agent'] = "sevk-ruby/#{VERSION}"
        conn.adapter Faraday.default_adapter
      end
    end

    def build_url(path)
      base = base_url.sub(%r{/+\z}, '')
      path = "/#{path}" unless path.start_with?('/')
      "#{base}#{path}"
    end

    def request(method, path, body = nil, headers: nil)
      url = build_url(path)
      body = encode_body(body) if !body.nil? && %i[post patch put].include?(method)
      response = case method
                 when :get
                   connection.get(url, body)
                 when :post
                   connection.post(url, body) { |req| apply_extra_headers(req, headers) }
                 when :patch
                   connection.patch(url, body) { |req| apply_extra_headers(req, headers) }
                 when :put
                   connection.put(url, body) { |req| apply_extra_headers(req, headers) }
                 when :delete
                   connection.delete(url)
                 end

      handle_response(response)
    rescue Faraday::TimeoutError => e
      raise Error.new(e.message, status_code: 0, code: 'TIMEOUT')
    rescue Faraday::ConnectionFailed => e
      code = e.wrapped_exception.is_a?(Net::OpenTimeout) ? 'TIMEOUT' : 'NETWORK_ERROR'
      raise Error.new(e.message, status_code: 0, code: code)
    rescue Faraday::Error => e
      raise Error.new(e.message, status_code: 0, code: 'NETWORK_ERROR')
    end

    def encode_body(body)
      JSON.generate(body)
    rescue JSON::GeneratorError, JSON::NestingError => e
      raise Error.new("Request body cannot be JSON encoded: #{e.message}", status_code: 0, code: 'SERIALIZATION_ERROR')
    end

    def apply_extra_headers(req, headers)
      return unless headers

      headers.each { |k, v| req.headers[k.to_s] = v.to_s }
    end

    def handle_response(response)
      return {} if response.status == 204

      if (200..299).cover?(response.status)
        raw_body = response.body
        body = decode_json_body(raw_body)
        unless body.is_a?(Hash)
          raise Error.new(
            'Expected a JSON response body but received an empty or non-JSON response',
            status_code: response.status,
            code: 'INVALID_RESPONSE',
            response: raw_body
          )
        end

        return body
      end

      raise_response_error(response.status, response.body, response.headers)
    end

    def raise_response_error(response_status, response_body, response_headers)
      decoded_body = decode_json_body(response_body)
      payload = error_payload(decoded_body)
      fields = normalize_fields(payload['fields'])
      status = response_status
      code = payload['code']
      code = 'UNKNOWN_ERROR' unless code.is_a?(String) && !code.empty?
      attrs = {
        status_code: status,
        code: code,
        fields: fields,
        retry_after: parse_retry_after(response_headers['Retry-After']),
        response: decoded_body,
        details: payload['details']
      }
      message = error_message(status, payload, decoded_body)

      case status
      when 400
        klass = fields.empty? && payload['code'] != 'VALIDATION_ERROR' ? BadRequestError : ValidationError
        raise klass.new(message, **attrs)
      when 401
        raise UnauthorizedError.new(message, **attrs)
      when 403
        raise ForbiddenError.new(message, **attrs)
      when 404
        raise NotFoundError.new(message, **attrs)
      when 409
        raise ConflictError.new(message, **attrs)
      when 422
        raise ValidationError.new(message, **attrs)
      when 429
        raise RateLimitError.new(message, **attrs)
      when 500..599
        raise InternalServerError.new(message, **attrs)
      else
        raise Error.new(message, **attrs)
      end
    end

    def decode_json_body(body)
      return body unless body.is_a?(String)

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    # Unwrap the nested `{ "error": { ... } }` envelope when present.
    def error_payload(body)
      return {} unless body.is_a?(Hash)

      nested = body['error']
      nested.is_a?(Hash) ? nested : body
    end

    def error_message(status, payload, body)
      message = payload['message']
      raw = body.is_a?(String) ? body.strip : ''
      if message.is_a?(String) && !message.empty?
        message
      else
        (raw.empty? ? "HTTP #{status}" : raw)
      end
    end

    # Coerce each field value (a string or list of strings on the wire) into a
    # list of strings.
    def normalize_fields(raw)
      return {} unless raw.is_a?(Hash)

      raw.each_with_object({}) do |(key, value), acc|
        acc[key.to_s] = value.is_a?(Array) ? value.map(&:to_s) : [value.to_s]
      end
    end

    # Integer-seconds Retry-After only; HTTP-date forms are ignored (nil).
    def parse_retry_after(value)
      text = value.to_s.strip
      return nil unless text.match?(/\A\d+\z/)

      seconds = text.to_i
      seconds <= 2_147_483_647 ? seconds : nil
    end
  end
end

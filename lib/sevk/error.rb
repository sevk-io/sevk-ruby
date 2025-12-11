# frozen_string_literal: true

module Sevk
  class Error < StandardError
    attr_reader :status_code, :code, :response

    def initialize(message = nil, status_code: nil, code: nil, response: nil)
      @status_code = status_code
      @code = code
      @response = response
      super(message)
    end

    def not_found?
      status_code == 404
    end

    def unauthorized?
      status_code == 401
    end

    def forbidden?
      status_code == 403
    end

    def bad_request?
      status_code == 400
    end

    def server_error?
      status_code.to_i >= 500 && status_code.to_i < 600
    end
  end

  class AuthenticationError < Error; end
  class NotFoundError < Error; end
  class ValidationError < Error; end
  class RateLimitError < Error; end
  class ServerError < Error; end
end

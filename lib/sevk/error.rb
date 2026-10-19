# frozen_string_literal: true

module Sevk
  class Error < StandardError
    attr_reader :status_code, :code, :fields, :retry_after, :response, :details

    def initialize(
      message = nil,
      status_code: nil,
      code: nil,
      fields: nil,
      retry_after: nil,
      response: nil,
      details: nil
    )
      @status_code = status_code
      @code = code
      @fields = fields || {}
      @retry_after = retry_after
      @response = response
      @details = details
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

    def conflict?
      status_code == 409
    end

    def validation_error?
      status_code == 422 ||
        (status_code == 400 && (code == 'VALIDATION_ERROR' || !fields.empty?))
    end

    def rate_limited?
      status_code == 429
    end

    def server_error?
      status_code.to_i >= 500 && status_code.to_i < 600
    end
  end

  class BadRequestError < Error; end
  class UnauthorizedError < Error; end
  class ForbiddenError < Error; end
  class NotFoundError < Error; end
  class ConflictError < Error; end

  class ValidationError < Error
    def initialize(message = nil, status_code: 0, code: 'VALIDATION_ERROR', **attributes)
      super
    end
  end

  class RateLimitError < Error; end
  class InternalServerError < Error; end
end

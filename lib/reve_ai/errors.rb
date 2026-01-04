# frozen_string_literal: true

module ReveAI
  # Base error class for all ReveAI errors
  class Error < StandardError; end

  # Raised when configuration is invalid or missing
  class ConfigurationError < Error; end

  # Raised when input validation fails before API call
  class ValidationError < Error; end

  # Network-level errors
  class NetworkError < Error; end
  class TimeoutError < NetworkError; end
  class ConnectionError < NetworkError; end

  # Base class for API errors with rich metadata
  class APIError < Error
    attr_reader :status, :body, :headers

    def initialize(message = nil, status: nil, body: nil, headers: nil)
      @status = status
      @body = body || {}
      @headers = headers || {}
      super(message)
    end

    def request_id
      headers["x-reve-request-id"]
    end

    def error_code
      body[:error_code]
    end
  end

  # 4xx Client errors
  class BadRequestError < APIError; end
  class UnauthorizedError < APIError; end
  class InsufficientCreditsError < APIError; end
  class ForbiddenError < APIError; end
  class NotFoundError < APIError; end
  class UnprocessableEntityError < APIError; end

  # Raised when rate limit is exceeded (429)
  class RateLimitError < APIError
    # Returns the retry-after header value in seconds
    def retry_after
      headers["retry-after"]&.to_i
    end
  end

  # 5xx Server errors
  class ServerError < APIError; end
end

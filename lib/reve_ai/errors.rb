# frozen_string_literal: true

module ReveAI
  # Base error class for all ReveAI errors.
  #
  # All library exceptions inherit from this class.
  #
  # @example Catching all ReveAI errors
  #   begin
  #     client.images.create(prompt: "A cat")
  #   rescue ReveAI::Error => e
  #     puts "ReveAI error: #{e.message}"
  #   end
  class Error < StandardError; end

  # Raised when configuration is invalid or missing.
  #
  # @example
  #   client = ReveAI::Client.new(api_key: nil)
  #   # => ReveAI::ConfigurationError: API key is required
  class ConfigurationError < Error; end

  # Raised when input validation fails before making an API call.
  #
  # @example Invalid prompt
  #   client.images.create(prompt: "")
  #   # => ReveAI::ValidationError: Prompt is required
  #
  # @example Invalid aspect ratio
  #   client.images.create(prompt: "A cat", aspect_ratio: "5:3")
  #   # => ReveAI::ValidationError: Invalid aspect_ratio '5:3'. Must be one of: 16:9, 9:16, ...
  class ValidationError < Error; end

  # Base class for network-level errors.
  #
  # Indicates connection or transport failures rather than API errors.
  class NetworkError < Error; end

  # Raised when a request times out.
  #
  # @example
  #   # Request exceeded timeout
  #   client.images.create(prompt: "A complex scene...")
  #   # => ReveAI::TimeoutError: Request timed out: execution expired
  class TimeoutError < NetworkError; end

  # Raised when unable to establish a connection to the API.
  #
  # @example
  #   # DNS failure or network unreachable
  #   # => ReveAI::ConnectionError: Connection failed: getaddrinfo: nodename nor servname provided
  class ConnectionError < NetworkError; end

  # Base class for API errors with HTTP status and response details.
  #
  # All API-related exceptions inherit from this class and include
  # HTTP status code, response body, and headers for debugging.
  #
  # @example Handling API errors
  #   begin
  #     client.images.create(prompt: "...")
  #   rescue ReveAI::UnauthorizedError => e
  #     puts "Auth failed: #{e.message}"
  #     puts "Status: #{e.status}"
  #   rescue ReveAI::RateLimitError => e
  #     puts "Rate limited, retry after #{e.retry_after} seconds"
  #   rescue ReveAI::APIError => e
  #     puts "API error (#{e.status}): #{e.message}"
  #     puts "Request ID: #{e.request_id}"
  #   end
  class APIError < Error
    # @return [Integer, nil] HTTP status code
    attr_reader :status

    # @return [Hash, String] Response body parsed as Hash, or raw String
    #   for binary error responses (e.g., grey image bodies)
    attr_reader :body

    # @return [Hash] Response headers
    attr_reader :headers

    # @return [Hash, nil] Additional error details from the response body
    attr_reader :params

    # Creates a new API error instance.
    #
    # @param message [String, nil] Error message
    # @param status [Integer, nil] HTTP status code
    # @param body [Hash, String, nil] Response body
    # @param headers [Hash, nil] Response headers
    def initialize(message = nil, status: nil, body: nil, headers: nil)
      @status = status
      @body = body || {}
      @headers = headers || {}
      @params = @body.is_a?(Hash) ? @body[:params] : nil
      super(message)
    end

    # Returns the request ID from response headers.
    #
    # Useful for debugging and support requests.
    #
    # @return [String, nil] Request ID if present
    def request_id
      headers["x-reve-request-id"]
    end

    # Returns the error code for this error.
    #
    # Read from the response body when present, falling back to the
    # X-Reve-Error-Code header: with an image Accept header, the API answers
    # errors with a small grey image body and no JSON error code.
    #
    # @return [String, nil] Error code (e.g., "PROMPT_TOO_LONG", "INVALID_API_KEY")
    def error_code
      return body[:error_code] if body.is_a?(Hash) && body[:error_code]

      headers["x-reve-error-code"]
    end
  end

  # Raised on 400 Bad Request responses.
  #
  # Indicates invalid request parameters or malformed request body.
  #
  # @example
  #   # Prompt too long
  #   client.images.create(prompt: "x" * 10000)
  #   # => ReveAI::BadRequestError: Prompt exceeds maximum length
  class BadRequestError < APIError; end

  # Raised on 401 Unauthorized responses.
  #
  # Indicates invalid or missing API key.
  #
  # @example
  #   client = ReveAI::Client.new(api_key: "invalid-key")
  #   client.images.create(prompt: "A cat")
  #   # => ReveAI::UnauthorizedError: Invalid API key
  class UnauthorizedError < APIError; end

  # Raised on 402 Payment Required responses.
  #
  # Indicates the account has run out of credits.
  #
  # @example
  #   # Account has insufficient credits
  #   client.images.create(prompt: "A cat")
  #   # => ReveAI::InsufficientCreditsError: Your budget has run out
  class InsufficientCreditsError < APIError; end

  # Raised on 403 Forbidden responses.
  #
  # Indicates the API key lacks permission for the requested operation.
  class ForbiddenError < APIError; end

  # Raised on 404 Not Found responses.
  #
  # Indicates the requested resource does not exist.
  class NotFoundError < APIError; end

  # Raised on 422 Unprocessable Entity responses.
  #
  # Indicates the inputs could not be understood or processed.
  #
  # @example
  #   # Invalid reference image format
  #   client.images.edit(edit_instruction: "...", reference_image: "not-valid-base64")
  #   # => ReveAI::UnprocessableEntityError: The inputs could not be understood
  class UnprocessableEntityError < APIError; end

  # Raised on 429 Too Many Requests responses.
  #
  # Indicates the rate limit has been exceeded. Check {#retry_after}
  # to determine when to retry.
  #
  # @example
  #   begin
  #     client.images.create(prompt: "A cat")
  #   rescue ReveAI::RateLimitError => e
  #     sleep e.retry_after
  #     retry
  #   end
  class RateLimitError < APIError
    # Returns the retry-after header value in seconds.
    #
    # Indicates how long to wait before retrying the request.
    #
    # @return [Integer, nil] Seconds to wait before retrying
    def retry_after
      headers["retry-after"]&.to_i
    end
  end

  # Raised on 5xx server error responses.
  #
  # Indicates an internal server error on the Reve API side.
  # These are typically transient and can be retried.
  #
  # @example
  #   # Server error
  #   client.images.create(prompt: "A cat")
  #   # => ReveAI::ServerError: Internal server error
  class ServerError < APIError; end
end

# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module ReveAI
  # HTTP layer for API communication.
  module HTTP
    # Low-level HTTP client using Faraday.
    #
    # Handles connection management, request/response processing, error handling,
    # and automatic retries for transient failures.
    #
    # @api private
    class Client
      # @return [Hash{Integer => Class}] Mapping of HTTP status codes to error classes
      ERROR_CODE_MAP = {
        400 => BadRequestError,
        401 => UnauthorizedError,
        402 => InsufficientCreditsError,
        403 => ForbiddenError,
        404 => NotFoundError,
        422 => UnprocessableEntityError,
        429 => RateLimitError
      }.freeze

      # @return [Array<Integer>] HTTP status codes that trigger automatic retry
      RETRY_STATUSES = [429, 500, 502, 503, 504].freeze

      # @return [Configuration] Configuration instance for this client
      attr_reader :configuration

      # Creates a new HTTP client.
      #
      # @param configuration [Configuration] Configuration instance
      # @api private
      def initialize(configuration)
        @configuration = configuration
      end

      # Makes a POST request to the API.
      #
      # @param path [String] API endpoint path (e.g., "/v1/image/create")
      # @param body [Hash] Request body to send as JSON
      #
      # @return [Response] Parsed API response
      #
      # @raise [TimeoutError] if request times out
      # @raise [ConnectionError] if connection fails
      # @raise [NetworkError] for other network errors
      # @raise [BadRequestError] on 400 responses
      # @raise [UnauthorizedError] on 401 responses
      # @raise [InsufficientCreditsError] on 402 responses
      # @raise [ForbiddenError] on 403 responses
      # @raise [NotFoundError] on 404 responses
      # @raise [UnprocessableEntityError] on 422 responses
      # @raise [RateLimitError] on 429 responses
      # @raise [ServerError] on 5xx responses
      #
      # @api private
      def post(path, body = {})
        normalized_path = path.sub(%r{^/}, "")
        response = connection.post(normalized_path) { |req| req.body = JSON.generate(body) }
        handle_response(response)
      rescue Faraday::TimeoutError => e
        raise TimeoutError, "Request timed out: #{e.message}"
      rescue Faraday::ConnectionFailed => e
        handle_connection_failed(e)
      rescue Faraday::Error => e
        raise NetworkError, "Network error: #{e.message}"
      end

      private

      # Handles connection failed errors.
      #
      # Distinguishes between timeout errors (which may appear as connection failures)
      # and actual connection failures.
      #
      # @param error [Faraday::ConnectionFailed] The connection error
      # @raise [TimeoutError] if error indicates timeout
      # @raise [ConnectionError] otherwise
      # @api private
      def handle_connection_failed(error)
        raise TimeoutError, "Request timed out: #{error.message}" if error.message.include?("execution expired")

        raise ConnectionError, "Connection failed: #{error.message}"
      end

      # Returns the Faraday connection, creating it if needed.
      #
      # @return [Faraday::Connection] Configured Faraday connection
      # @api private
      def connection
        @connection ||= build_connection
      end

      # Builds a new Faraday connection with all middleware.
      #
      # @return [Faraday::Connection] New connection instance
      # @api private
      def build_connection
        Faraday.new(url: configuration.base_url) do |conn|
          configure_retry(conn)
          configure_headers(conn)
          configure_timeouts(conn)
          configure_logging(conn)
          conn.adapter Faraday.default_adapter
        end
      end

      # Configures retry middleware.
      #
      # @param conn [Faraday::Connection] Connection to configure
      # @api private
      def configure_retry(conn)
        conn.request :retry, max: configuration.max_retries, interval: 0.5,
                             backoff_factor: 2, retry_statuses: RETRY_STATUSES, methods: [:post]
      end

      # Configures request headers.
      #
      # @param conn [Faraday::Connection] Connection to configure
      # @api private
      def configure_headers(conn)
        conn.headers["Authorization"] = "Bearer #{configuration.api_key}"
        conn.headers["Content-Type"] = "application/json"
        conn.headers["Accept"] = "application/json"
        conn.headers["User-Agent"] = user_agent
      end

      # Configures connection and read timeouts.
      #
      # @param conn [Faraday::Connection] Connection to configure
      # @api private
      def configure_timeouts(conn)
        conn.options.timeout = configuration.timeout
        conn.options.open_timeout = configuration.open_timeout
      end

      # Configures response logging if debug mode is enabled.
      #
      # @param conn [Faraday::Connection] Connection to configure
      # @api private
      def configure_logging(conn)
        conn.response :logger, configuration.logger if configuration.debug && configuration.logger
      end

      # Returns the User-Agent header value.
      #
      # @return [String] User-Agent string
      # @api private
      def user_agent
        "reve-ai-ruby/#{ReveAI::VERSION} Ruby/#{RUBY_VERSION}"
      end

      # Processes the HTTP response.
      #
      # @param response [Faraday::Response] Raw Faraday response
      # @return [Response] Wrapped response on success
      # @raise [APIError] on error responses
      # @api private
      def handle_response(response)
        body = parse_body(response.body)
        return build_success_response(response, body) if response.status.between?(200, 299)

        raise_api_error(response.status, body, response.headers.to_h)
      end

      # Builds a successful response object.
      #
      # @param response [Faraday::Response] Raw response
      # @param body [Hash] Parsed body
      # @return [Response] Response wrapper
      # @api private
      def build_success_response(response, body)
        Response.new(status: response.status, headers: response.headers.to_h, body: body)
      end

      # Parses the response body as JSON.
      #
      # @param body [String, nil] Raw response body
      # @return [Hash] Parsed body, or empty hash if nil/empty
      # @api private
      def parse_body(body)
        return {} if body.nil? || body.empty?

        JSON.parse(body, symbolize_names: true)
      rescue JSON::ParserError
        { raw: body }
      end

      # Raises the appropriate API error for a status code.
      #
      # @param status [Integer] HTTP status code
      # @param body [Hash] Parsed response body
      # @param headers [Hash] Response headers
      # @raise [APIError] Appropriate error subclass
      # @api private
      def raise_api_error(status, body, headers)
        error_class = ERROR_CODE_MAP[status] || (status >= 500 ? ServerError : APIError)
        message = body[:message] || body[:error] || "Unknown error"
        raise error_class.new(message, status: status, body: body, headers: headers)
      end
    end
  end
end

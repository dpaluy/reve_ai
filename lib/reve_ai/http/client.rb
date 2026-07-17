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

      # Makes a GET request to the API.
      #
      # @param path [String] API endpoint path (e.g., "/v1/image/effect")
      # @param params [Hash, nil] Query parameters to merge into the URL
      #   (e.g., { source: "project" })
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
      def get(path, params: nil)
        normalized_path = path.sub(%r{^/}, "")
        response = perform_request do |conn|
          conn.get(normalized_path) { |req| req.params.update(params) if params }
        end
        handle_response(response)
      end

      # Makes a POST request to the API.
      #
      # @param path [String] API endpoint path (e.g., "/v1/image/create")
      # @param body [Hash] Request body to send as JSON
      # @param params [Hash, nil] Query parameters to merge into the URL
      #   (e.g., { breadcrumb: "my-tracking-value" })
      # @param accept [String, nil] Per-request Accept header override
      #   (e.g., "image/webp"). The connection default stays "application/json".
      #
      # @return [Response] Parsed API response. When the response Content-Type
      #   is +image/*+, the body is the raw image String (bytes), not a Hash.
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
      def post(path, body = {}, params: nil, accept: nil)
        normalized_path = path.sub(%r{^/}, "")
        response = perform_request do |conn|
          conn.post(normalized_path) do |req|
            req.params.update(params) if params
            req.headers["Accept"] = accept if accept
            req.body = JSON.generate(body)
          end
        end
        handle_response(response)
      end

      private

      # Performs an HTTP request, mapping Faraday errors to gem errors.
      #
      # @yieldparam connection [Faraday::Connection] Connection to perform the request on
      # @return [Faraday::Response] Raw Faraday response
      #
      # @raise [TimeoutError] if request times out
      # @raise [ConnectionError] if connection fails
      # @raise [NetworkError] for other network errors
      # @api private
      def perform_request
        yield connection
      rescue Faraday::TimeoutError => e
        raise TimeoutError, "Request timed out: #{e.message}"
      rescue Faraday::ConnectionFailed => e
        handle_connection_failed(e)
      rescue Faraday::Error => e
        raise NetworkError, "Network error: #{e.message}"
      end

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
                             backoff_factor: 2, retry_statuses: RETRY_STATUSES, methods: %i[post get]
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
        body = parse_body(response)
        return build_success_response(response, body) if response.status.between?(200, 299)

        raise_api_error(response.status, body, response.headers.to_h)
      end

      # Builds a successful response object.
      #
      # @param response [Faraday::Response] Raw response
      # @param body [Hash, String] Parsed body, or raw bytes for binary responses
      # @return [Response] Response wrapper
      # @api private
      def build_success_response(response, body)
        Response.new(status: response.status, headers: response.headers.to_h, body: body)
      end

      # Parses the response body.
      #
      # Bodies with an +image/*+ Content-Type are raw image bytes and are
      # returned as-is; anything else is parsed as JSON.
      #
      # @param response [Faraday::Response] Raw Faraday response
      # @return [Hash, String] Parsed body, raw bytes String for image
      #   responses, or empty hash if body is nil/empty
      # @api private
      def parse_body(response)
        raw = response.body
        return {} if raw.nil? || raw.empty?
        return raw if image_content?(response)

        JSON.parse(raw, symbolize_names: true)
      rescue JSON::ParserError
        { raw: raw }
      end

      # Checks whether the response carries raw image bytes.
      #
      # @param response [Faraday::Response] Raw Faraday response
      # @return [Boolean] true if Content-Type starts with "image/"
      # @api private
      def image_content?(response)
        response.headers["content-type"].to_s.start_with?("image/")
      end

      # Raises the appropriate API error for a status code.
      #
      # @param status [Integer] HTTP status code
      # @param body [Hash, String] Parsed response body
      # @param headers [Hash] Response headers
      # @raise [APIError] Appropriate error subclass
      # @api private
      def raise_api_error(status, body, headers)
        error_class = ERROR_CODE_MAP[status] || (status >= 500 ? ServerError : APIError)
        raise error_class.new(extract_error_message(body, headers), status: status, body: body, headers: headers)
      end

      # Extracts the error message from the response body.
      #
      # Falls back to the X-Reve-Error-Code header when the body carries no
      # message: with an image Accept header, the API answers errors with a
      # small grey image instead of a JSON error body.
      #
      # @param body [Hash, String] Parsed response body
      # @param headers [Hash] Response headers
      # @return [String] Error message
      # @api private
      def extract_error_message(body, headers)
        from_body = body.is_a?(Hash) ? body[:message] || body[:error] : nil
        from_body || headers["x-reve-error-code"] || "Unknown error"
      end
    end
  end
end

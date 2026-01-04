# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module ReveAI
  # HTTP layer for API communication
  module HTTP
    # Low-level HTTP client using Faraday
    class Client
      ERROR_CODE_MAP = {
        400 => BadRequestError,
        401 => UnauthorizedError,
        402 => InsufficientCreditsError,
        403 => ForbiddenError,
        404 => NotFoundError,
        422 => UnprocessableEntityError,
        429 => RateLimitError
      }.freeze

      RETRY_STATUSES = [429, 500, 502, 503, 504].freeze

      attr_reader :configuration

      def initialize(configuration)
        @configuration = configuration
      end

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

      def handle_connection_failed(error)
        raise TimeoutError, "Request timed out: #{error.message}" if error.message.include?("execution expired")

        raise ConnectionError, "Connection failed: #{error.message}"
      end

      def connection
        @connection ||= build_connection
      end

      def build_connection
        Faraday.new(url: configuration.base_url) do |conn|
          configure_retry(conn)
          configure_headers(conn)
          configure_timeouts(conn)
          configure_logging(conn)
          conn.adapter Faraday.default_adapter
        end
      end

      def configure_retry(conn)
        conn.request :retry, max: configuration.max_retries, interval: 0.5,
                             backoff_factor: 2, retry_statuses: RETRY_STATUSES, methods: [:post]
      end

      def configure_headers(conn)
        conn.headers["Authorization"] = "Bearer #{configuration.api_key}"
        conn.headers["Content-Type"] = "application/json"
        conn.headers["Accept"] = "application/json"
        conn.headers["User-Agent"] = user_agent
      end

      def configure_timeouts(conn)
        conn.options.timeout = configuration.timeout
        conn.options.open_timeout = configuration.open_timeout
      end

      def configure_logging(conn)
        conn.response :logger, configuration.logger if configuration.debug && configuration.logger
      end

      def user_agent
        "reve-ai-ruby/#{ReveAI::VERSION} Ruby/#{RUBY_VERSION}"
      end

      def handle_response(response)
        body = parse_body(response.body)
        return build_success_response(response, body) if response.status.between?(200, 299)

        raise_api_error(response.status, body, response.headers.to_h)
      end

      def build_success_response(response, body)
        Response.new(status: response.status, headers: response.headers.to_h, body: body)
      end

      def parse_body(body)
        return {} if body.nil? || body.empty?

        JSON.parse(body, symbolize_names: true)
      rescue JSON::ParserError
        { raw: body }
      end

      def raise_api_error(status, body, headers)
        error_class = ERROR_CODE_MAP[status] || (status >= 500 ? ServerError : APIError)
        message = body[:message] || body[:error] || "Unknown error"
        raise error_class.new(message, status: status, body: body, headers: headers)
      end
    end
  end
end

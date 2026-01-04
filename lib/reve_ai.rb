# frozen_string_literal: true

require_relative "reve_ai/version"
require_relative "reve_ai/errors"
require_relative "reve_ai/configuration"
require_relative "reve_ai/response"
require_relative "reve_ai/http/client"
require_relative "reve_ai/resources/base"
require_relative "reve_ai/resources/images"
require_relative "reve_ai/client"

# Ruby client for the Reve image generation API.
#
# ReveAI provides a lightweight Faraday-based wrapper for the Reve API,
# supporting image creation, editing, and remixing operations.
#
# @example Global configuration
#   ReveAI.configure do |config|
#     config.api_key = ENV["REVE_AI_API_KEY"]
#     config.timeout = 120
#   end
#
#   client = ReveAI::Client.new
#   result = client.images.create(prompt: "A sunset over mountains")
#
# @example Per-instance configuration
#   client = ReveAI.client(api_key: "your-api-key", timeout: 60)
#   result = client.images.create(prompt: "A sunset over mountains")
#
# @see Client
# @see Configuration
# @see https://api.reve.com/console/docs Reve API Documentation
module ReveAI
  class << self
    # @return [Configuration, nil] Global configuration instance
    attr_accessor :configuration

    # Configures global settings for all ReveAI clients.
    #
    # @yield [config] Configuration block
    # @yieldparam config [Configuration] Configuration instance to modify
    # @return [Configuration] The configuration instance
    #
    # @example
    #   ReveAI.configure do |config|
    #     config.api_key = "your-api-key"
    #     config.base_url = "https://api.reve.com"
    #     config.timeout = 120
    #     config.debug = true
    #   end
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Resets the global configuration to nil.
    #
    # Useful for testing or reinitializing the client.
    #
    # @return [nil]
    #
    # @example
    #   ReveAI.reset_configuration!
    def reset_configuration!
      self.configuration = nil
    end

    # Creates a new API client with optional per-instance configuration.
    #
    # This is a convenience method equivalent to calling {Client.new}.
    #
    # @param api_key [String, nil] API key (defaults to global config or ENV)
    # @param options [Hash] Additional configuration options
    # @option options [String] :base_url Base URL for API requests
    # @option options [Integer] :timeout Request timeout in seconds
    # @option options [Integer] :open_timeout Connection timeout in seconds
    # @option options [Integer] :max_retries Number of retry attempts
    # @option options [Logger] :logger Logger instance for debugging
    # @option options [Boolean] :debug Enable debug logging
    #
    # @return [Client] New client instance
    #
    # @example
    #   client = ReveAI.client(api_key: "your-key", timeout: 60)
    def client(api_key: nil, **options)
      Client.new(api_key: api_key, **options)
    end
  end
end

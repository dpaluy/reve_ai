# frozen_string_literal: true

module ReveAI
  # Configuration settings for the ReveAI client.
  #
  # Stores API credentials and connection settings. Can be configured globally
  # via {ReveAI.configure} or per-instance when creating a {Client}.
  #
  # @example Global configuration
  #   ReveAI.configure do |config|
  #     config.api_key = ENV["REVE_AI_API_KEY"]
  #     config.timeout = 120
  #     config.debug = true
  #   end
  #
  # @example Environment variable
  #   # Set REVE_AI_API_KEY environment variable
  #   export REVE_AI_API_KEY="your-api-key"
  #
  #   # API key is automatically loaded
  #   client = ReveAI::Client.new
  #
  # @see Client
  class Configuration
    # @return [String] Default base URL for the Reve API
    DEFAULT_BASE_URL = "https://api.reve.com"

    # @return [Integer] Default request timeout in seconds (2 minutes for image generation)
    DEFAULT_TIMEOUT = 120

    # @return [Integer] Default connection open timeout in seconds
    DEFAULT_OPEN_TIMEOUT = 30

    # @return [Integer] Default number of retry attempts for failed requests
    DEFAULT_MAX_RETRIES = 2

    # @return [Array<String>] Valid aspect ratios for image generation
    VALID_ASPECT_RATIOS = %w[16:9 9:16 3:2 2:3 4:3 3:4 1:1].freeze

    # @return [Integer] Maximum allowed prompt length in characters
    MAX_PROMPT_LENGTH = 2560

    # @return [Integer] Maximum number of reference images for remix operations
    MAX_REFERENCE_IMAGES = 6

    # @return [String, nil] Reve API key for authentication
    attr_accessor :api_key

    # @return [String] Base URL for API requests (defaults to https://api.reve.com)
    attr_accessor :base_url

    # @return [Integer] Request timeout in seconds
    attr_accessor :timeout

    # @return [Integer] Connection open timeout in seconds
    attr_accessor :open_timeout

    # @return [Integer] Number of retry attempts for transient failures
    attr_accessor :max_retries

    # @return [Logger, nil] Logger instance for debug output
    attr_accessor :logger

    # @return [Boolean] Enable debug logging of HTTP requests/responses
    attr_accessor :debug

    # Creates a new configuration with default values.
    #
    # Automatically loads API key from the REVE_AI_API_KEY environment variable
    # if present.
    #
    # @example
    #   config = ReveAI::Configuration.new
    #   config.api_key = "your-api-key"
    #   config.timeout = 60
    def initialize
      @api_key = ENV.fetch("REVE_AI_API_KEY", nil)
      @base_url = DEFAULT_BASE_URL
      @timeout = DEFAULT_TIMEOUT
      @open_timeout = DEFAULT_OPEN_TIMEOUT
      @max_retries = DEFAULT_MAX_RETRIES
      @logger = nil
      @debug = false
    end

    # Checks if the configuration has a valid API key.
    #
    # @return [Boolean] true if api_key is present and not empty
    #
    # @example
    #   config = ReveAI::Configuration.new
    #   config.valid? # => false
    #
    #   config.api_key = "your-key"
    #   config.valid? # => true
    def valid?
      !api_key.nil? && !api_key.empty?
    end
  end
end

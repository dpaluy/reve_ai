# frozen_string_literal: true

module ReveAI
  # HTTP client for the Reve image generation API.
  #
  # Provides access to all Reve API endpoints through resource objects.
  # Configure globally via {ReveAI.configure} or pass parameters directly
  # to the constructor.
  #
  # @example Using global configuration
  #   ReveAI.configure do |config|
  #     config.api_key = ENV["REVE_AI_API_KEY"]
  #   end
  #
  #   client = ReveAI::Client.new
  #   result = client.images.create(prompt: "A cat wearing a hat")
  #
  # @example Using per-instance configuration
  #   client = ReveAI::Client.new(
  #     api_key: "your-key",
  #     timeout: 60
  #   )
  #
  # @see Resources::Images
  # @see Configuration
  class Client
    # @return [Configuration] Configuration instance for this client
    attr_reader :configuration

    # Creates a new Reve API client.
    #
    # @param api_key [String, nil] API key (defaults to global config or ENV["REVE_AI_API_KEY"])
    # @param options [Hash] Additional configuration options
    # @option options [String] :base_url Base URL for API requests
    # @option options [Integer] :timeout Request timeout in seconds
    # @option options [Integer] :open_timeout Connection timeout in seconds
    # @option options [Integer] :max_retries Number of retry attempts
    # @option options [Logger] :logger Logger instance for debugging
    # @option options [Boolean] :debug Enable debug logging
    #
    # @raise [ConfigurationError] if api_key is missing or empty
    #
    # @example
    #   client = ReveAI::Client.new(api_key: "your-api-key")
    def initialize(api_key: nil, **options)
      @configuration = build_configuration(api_key, options)
      validate_configuration!
    end

    # Returns the Images resource for image generation operations.
    #
    # @return [Resources::Images] Image operations interface
    # @see Resources::Images
    #
    # @example Generate an image
    #   result = client.images.create(prompt: "A sunset over mountains")
    #   puts result.base64 # Base64 encoded PNG
    #
    # @example Edit an image
    #   result = client.images.edit(
    #     edit_instruction: "Make the sky more blue",
    #     reference_image: base64_encoded_image
    #   )
    #
    # @example Remix images
    #   result = client.images.remix(
    #     prompt: "Combine <img>1</img> and <img>2</img> into one scene",
    #     reference_images: [image1_base64, image2_base64]
    #   )
    def images
      @images ||= Resources::Images.new(self)
    end

    # Returns the HTTP client for making API requests.
    #
    # @return [HTTP::Client] HTTP client instance
    # @api private
    def http_client
      @http_client ||= HTTP::Client.new(configuration)
    end

    private

    # Builds configuration from global config and options.
    #
    # @param api_key [String, nil] API key override
    # @param options [Hash] Configuration options
    # @return [Configuration] Merged configuration
    # @api private
    def build_configuration(api_key, options)
      config = ReveAI.configuration&.dup || Configuration.new
      config.api_key = api_key if api_key
      options.each { |key, value| config.public_send("#{key}=", value) }
      config
    end

    # Validates that required configuration is present.
    #
    # @raise [ConfigurationError] if API key is missing
    # @api private
    def validate_configuration!
      raise ConfigurationError, "API key is required" unless configuration.valid?
    end
  end
end

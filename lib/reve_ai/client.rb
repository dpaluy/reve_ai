# frozen_string_literal: true

module ReveAI
  # Main client for interacting with the Reve API
  class Client
    attr_reader :configuration

    def initialize(api_key: nil, **options)
      @configuration = build_configuration(api_key, options)
      validate_configuration!
    end

    def images
      @images ||= Resources::Images.new(self)
    end

    def http_client
      @http_client ||= HTTP::Client.new(configuration)
    end

    private

    def build_configuration(api_key, options)
      config = ReveAI.configuration&.dup || Configuration.new
      config.api_key = api_key if api_key
      options.each { |key, value| config.public_send("#{key}=", value) }
      config
    end

    def validate_configuration!
      raise ConfigurationError, "API key is required" unless configuration.valid?
    end
  end
end

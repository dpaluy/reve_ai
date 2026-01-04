# frozen_string_literal: true

module ReveAI
  # Configuration settings for the ReveAI client
  class Configuration
    DEFAULT_BASE_URL = "https://api.reve.com"
    DEFAULT_TIMEOUT = 120
    DEFAULT_OPEN_TIMEOUT = 30
    DEFAULT_MAX_RETRIES = 2

    VALID_ASPECT_RATIOS = %w[16:9 9:16 3:2 2:3 4:3 3:4 1:1].freeze
    MAX_PROMPT_LENGTH = 2560
    MAX_REFERENCE_IMAGES = 6

    attr_accessor :api_key, :base_url, :timeout, :open_timeout, :max_retries, :logger, :debug

    def initialize
      @api_key = ENV.fetch("REVE_AI_API_KEY", nil)
      @base_url = DEFAULT_BASE_URL
      @timeout = DEFAULT_TIMEOUT
      @open_timeout = DEFAULT_OPEN_TIMEOUT
      @max_retries = DEFAULT_MAX_RETRIES
      @logger = nil
      @debug = false
    end

    def valid?
      !api_key.nil? && !api_key.empty?
    end
  end
end

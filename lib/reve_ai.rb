# frozen_string_literal: true

require_relative "reve_ai/version"
require_relative "reve_ai/errors"
require_relative "reve_ai/configuration"
require_relative "reve_ai/response"
require_relative "reve_ai/http/client"
require_relative "reve_ai/resources/base"
require_relative "reve_ai/resources/images"
require_relative "reve_ai/client"

# Ruby client for the Reve image generation API (aimlapi.com)
module ReveAI
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def reset_configuration!
      self.configuration = nil
    end

    def client(api_key: nil, **options)
      Client.new(api_key: api_key, **options)
    end
  end
end

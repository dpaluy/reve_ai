# frozen_string_literal: true

module ReveAI
  module Resources
    # Namespace for Reve API v2 resources.
    #
    # Accessed via `client.v2`. Groups the v2 image create endpoint and the
    # experimental layout pipeline endpoints.
    #
    # @example Generate an image with the v2 API
    #   result = client.v2.images.create(prompt: "A sunset over mountains")
    #   result.layout # => { prompt: "...", regions: [...] }
    #
    # @see https://api.reve.com/console/docs Reve API Documentation
    class V2
      # @return [Client] The client instance for this namespace
      attr_reader :client

      # Creates a new v2 namespace.
      #
      # @param client [Client] The API client
      # @api private
      def initialize(client)
        @client = client
      end

      # Returns the v2 images resource.
      #
      # @return [V2::Images] v2 image generation operations
      def images
        @images ||= Images.new(client)
      end

      # Returns the v2 layouts resource (experimental endpoints).
      #
      # @return [V2::Layouts] v2 layout pipeline operations
      def layouts
        @layouts ||= Layouts.new(client)
      end
    end
  end
end

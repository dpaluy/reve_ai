# frozen_string_literal: true

module ReveAI
  module Resources
    # Effects listing operations.
    #
    # Lists the effects available to the project associated with the API key,
    # including saved project effects and built-in presets. Names from this
    # list can be applied to any generation via the +postprocessing+ parameter
    # of the image resources (see Images#create).
    #
    # @example List all effects
    #   client = ReveAI::Client.new(api_key: "your-key")
    #   result = client.effects.list
    #   result.body[:effects].each { |effect| puts effect[:name] }
    #
    # @note The list returns effect names only — effect parameter definitions
    #   are not included. Configure effect presets in the Reve application,
    #   save them with a name, and apply that name from the API.
    # @see https://api.reve.com/console/docs Reve API Documentation
    class Effects < Base
      # @return [String] API endpoint for listing effects
      LIST_ENDPOINT = "/v1/image/effect"

      # @return [Array<String>] Valid values for the +source+ filter
      VALID_SOURCES = %w[all project preset].freeze

      # Lists effects available to the project.
      #
      # The default response includes both saved project effects (+source+
      # "saved") and built-in presets (+source+ "builtin"). Each entry in
      # +body[:effects]+ carries +name+ and +source+, plus optional
      # +description+ and +category+ (e.g., "color", "textures") when
      # available. Use a returned +name+ as +effect_name+ in postprocessing
      # requests.
      #
      # @param source [String, nil] Filter by effect origin: "all" (default),
      #   "project" (saved project effects only), or "preset" (builtin only)
      # @param breadcrumb [String, nil] Request tracking label sent as the
      #   +breadcrumb+ query param; ignored by the API, searchable in the
      #   Usage page
      #
      # @return [Response] Response whose +body[:effects]+ is an Array of
      #   effect Hashes with +name+, +source+, and optional +description+
      #   and +category+ keys
      #
      # @raise [ValidationError] if source is not one of "all", "project", "preset"
      # @raise [UnauthorizedError] if API key is invalid
      # @raise [RateLimitError] if rate limit is exceeded
      #
      # @example List all effects
      #   result = client.effects.list
      #   result.body[:effects].map { |effect| effect[:name] }
      #
      # @example List only saved project effects
      #   result = client.effects.list(source: "project")
      #
      # @see https://api.reve.com/console/docs Reve API Documentation
      def list(source: nil, breadcrumb: nil)
        validate_source!(source)

        params = {}
        params[:source] = source if source
        params[:breadcrumb] = breadcrumb if breadcrumb

        get(LIST_ENDPOINT, params: params.empty? ? nil : params)
      end

      private

      # Validates the source filter.
      #
      # @param source [String, nil] The source filter to validate
      # @raise [ValidationError] if source is not one of {VALID_SOURCES}
      # @api private
      def validate_source!(source)
        return if source.nil? || VALID_SOURCES.include?(source)

        raise ValidationError, "Invalid source '#{source}'. Must be one of: #{VALID_SOURCES.join(", ")}"
      end
    end
  end
end

# frozen_string_literal: true

require_relative "../base"

module ReveAI
  module Resources
    class V2
      # v2 image generation operations.
      #
      # The v2 create endpoint unifies the v1 create, edit, and remix
      # workflows: a single prompt plus an ordered list of reference images.
      # JSON responses include a structured +layout+ alongside the image.
      #
      # @example Generate an image from text
      #   result = client.v2.images.create(prompt: "A sunset over mountains")
      #   result.base64 # Base64 encoded PNG
      #   result.layout # => { prompt: "...", regions: [...] }
      #
      # @note Image generation requests commonly take 40-80 seconds; the API
      #   documentation mandates request timeouts of at least 120 seconds
      #   (the gem default).
      #
      # @see https://api.reve.com/console/docs Reve API Documentation
      class Images < Base
        # @return [String] API endpoint for v2 image creation
        CREATE_ENDPOINT = "/v2/image/create"

        # Generates an image from a text prompt with optional reference images.
        #
        # Reference images are addressed from the prompt with `<frame>N</frame>`
        # tags, where N is the 0-based index into the +references+ array (so
        # the first reference is `<frame>0</frame>`).
        #
        # @param prompt [String] Text description of the desired image
        #   (max 4000 chars); may contain `<frame>N</frame>` reference tags
        # @param references [Array<Hash>, nil] Up to 8 reference images
        #   ({Configuration::V2_MAX_REFERENCES}). Each entry is a Hash with
        #   exactly one of +data+ (base64 encoded image String) or +ref+
        #   (identifier String: +"id:<uuid>"+ for a previously stored image or
        #   generation, +"reference:@<name>"+ for a named reference in your
        #   project). Entries are serialized as given.
        # @param aspect_ratio [String, nil] Output aspect ratio (defaults to
        #   the API default of "auto", which lets the model pick); v2 supports
        #   the full set in {Configuration::ASPECT_RATIOS}, including "auto"
        #   and "4:1"
        # @param postprocessing [Array<Hash>, nil] Postprocessing steps, each
        #   with a +process+ key (e.g., { process: "upscale", upscale_factor: 2 })
        # @param test_time_scaling [Numeric, nil] Scaling factor (1-15);
        #   values above 1 cost more credits
        # @param version [String, nil] Optional public model version alias,
        #   passed through as-is (e.g., "latest", "reve-v2-create@260601")
        # @param accept [String, nil] Per-request Accept header: "image/png",
        #   "image/jpeg", or "image/webp" for a binary image response, or
        #   "application/json" (default)
        # @param breadcrumb [String, nil] Request tracking value sent as the
        #   +breadcrumb+ query parameter; ignored by the API
        #
        # @return [ImageResponse] Response containing the image and, on JSON
        #   responses, the generated +layout+
        #
        # @raise [ValidationError] if prompt is empty or exceeds 4000 characters
        # @raise [ValidationError] if references is malformed or exceeds 8 entries
        # @raise [ValidationError] if aspect_ratio is invalid
        # @raise [ValidationError] if postprocessing or test_time_scaling is invalid
        # @raise [BadRequestError] if API rejects the request
        # @raise [UnauthorizedError] if API key is invalid
        # @raise [InsufficientCreditsError] if account has no credits
        # @raise [RateLimitError] if rate limit is exceeded
        #
        # @example Text-to-image (no references)
        #   result = client.v2.images.create(
        #     prompt: "A serene mountain landscape at sunset",
        #     aspect_ratio: "16:9"
        #   )
        #
        # @example Edit-style: one reference addressed as <frame>0</frame>
        #   result = client.v2.images.create(
        #     prompt: "Remove the people in the background of <frame>0</frame>.",
        #     references: [{ data: original_image_base64 }]
        #   )
        #
        # @example Remix-style: combine two references
        #   result = client.v2.images.create(
        #     prompt: "The woman from <frame>0</frame> driving the car from <frame>1</frame>.",
        #     references: [{ data: woman_base64 }, { data: car_base64 }]
        #   )
        #
        # @note v2 images are significantly larger than v1 images; the API
        #   documentation suggests capping the output size with
        #   +postprocessing: [{ process: "fit_image", max_dim: 2048 }]+.
        # @note The API documentation does not recommend +test_time_scaling+
        #   for v2 models.
        #
        # @see https://api.reve.com/console/docs Reve API Documentation
        def create(prompt:, references: nil, aspect_ratio: nil, postprocessing: nil,
                   test_time_scaling: nil, version: nil, accept: nil, breadcrumb: nil)
          validate_prompt!(prompt, max_length: Configuration::V2_MAX_PROMPT_LENGTH)
          validate_references!(references)
          validate_aspect_ratio!(aspect_ratio, Configuration::ASPECT_RATIOS)
          validate_postprocessing!(postprocessing)
          validate_test_time_scaling!(test_time_scaling)

          body = build_create_body(prompt: prompt, references: references, aspect_ratio: aspect_ratio,
                                   postprocessing: postprocessing, test_time_scaling: test_time_scaling,
                                   version: version)
          params = breadcrumb ? { breadcrumb: breadcrumb } : nil

          response = post(CREATE_ENDPOINT, body, params: params, accept: accept)
          ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
        end

        private

        # Builds the request body for the create endpoint.
        #
        # @return [Hash] Request body with only the provided options
        # @api private
        def build_create_body(prompt:, references:, aspect_ratio:, postprocessing:, test_time_scaling:, version:)
          body = { prompt: prompt }
          body[:references] = references if references
          body[:aspect_ratio] = aspect_ratio if aspect_ratio
          body[:postprocessing] = postprocessing if postprocessing
          body[:test_time_scaling] = test_time_scaling if test_time_scaling
          body[:version] = version if version
          body
        end

        # Validates the references array.
        #
        # @param references [Array<Hash>, nil] Reference image entries
        # @raise [ValidationError] if not an Array, exceeds the maximum, or
        #   contains a malformed entry
        # @api private
        def validate_references!(references)
          return if references.nil?

          unless references.is_a?(Array)
            raise ValidationError, "References must be an Array of Hashes with exactly one of 'data' or 'ref'"
          end

          max = Configuration::V2_MAX_REFERENCES
          raise ValidationError, "Maximum #{max} references allowed" if references.length > max

          references.each_with_index { |reference, index| validate_reference!(reference, index) }
        end

        # Validates a single reference entry.
        #
        # @param reference [Hash] Reference entry with exactly one of +data+ or +ref+
        # @param index [Integer] Position in the references array (for error messages)
        # @raise [ValidationError] if the entry is not a Hash, has both or
        #   neither of +data+/+ref+, or has a non-String value
        # @api private
        def validate_reference!(reference, index)
          unless reference.is_a?(Hash)
            raise ValidationError, "Reference at index #{index} must be a Hash with exactly one of 'data' or 'ref'"
          end

          data = reference[:data] || reference["data"]
          ref = reference[:ref] || reference["ref"]

          if data.nil? == ref.nil?
            raise ValidationError, "Reference at index #{index} must include exactly one of 'data' or 'ref'"
          end

          if data.nil?
            validate_reference_value!(ref, "ref", index)
          else
            validate_reference_value!(data, "data", index)
          end
        end

        # Validates a reference +data+ or +ref+ value.
        #
        # @param value [Object] The data or ref value
        # @param key [String] Which key the value came from ("data" or "ref")
        # @param index [Integer] Position in the references array
        # @raise [ValidationError] if value is not a non-empty String
        # @api private
        def validate_reference_value!(value, key, index)
          return if value.is_a?(String) && !value.empty?

          raise ValidationError, "Reference at index #{index} '#{key}' must be a non-empty String"
        end
      end
    end
  end
end

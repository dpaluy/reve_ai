# frozen_string_literal: true

require_relative "../base"

module ReveAI
  module Resources
    class V2
      # v2 layout pipeline operations (experimental).
      #
      # The layout endpoints expose lower-level control over image
      # composition: extracting structured layouts from images, generating
      # layouts from prompts, and rendering images from layouts.
      #
      # @note Experimental: these endpoints require care and experimentation
      #   to achieve good results. For simple image generation and
      #   prompt-based editing, prefer {V2::Images#create}.
      #
      # @see https://api.reve.com/console/docs Reve API Documentation
      class Layouts < Base
        # @return [String] API endpoint for layout extraction
        EXTRACT_ENDPOINT = "/v2/image/extract_layout"

        # @return [String] API endpoint for layout generation
        CREATE_ENDPOINT = "/v2/image/create_layout"

        # @return [String] API endpoint for layout rendering
        RENDER_ENDPOINT = "/v2/image/render_layout"

        # Extracts a structured layout from an image.
        #
        # @param image [Hash] Source image: exactly one of +data+ (base64
        #   encoded image String) or +ref+ (identifier String: +"id:<uuid>"+
        #   or +"reference:@<name>"+)
        # @param prompt [String, nil] Optional instruction for transforming
        #   the extracted layout (max 4000 chars)
        # @param version [String, nil] Optional public model version alias
        # @param breadcrumb [String, nil] Request tracking value sent as the
        #   +breadcrumb+ query parameter; ignored by the API
        #
        # @return [LayoutResponse] Response containing the extracted +layout+
        #
        # @raise [ValidationError] if image is malformed or prompt exceeds max length
        #
        # @example Extract a layout from an image
        #   result = client.v2.layouts.extract(image: { data: photo_base64 })
        #   result.layout # => { prompt: "...", regions: [...], width: 4672, height: 3520 }
        #
        # @note Experimental: layout extraction commonly takes 10-40 seconds.
        def extract(image:, prompt: nil, version: nil, breadcrumb: nil)
          validate_raw_image!(image, "Image")
          validate_prompt!(prompt, max_length: Configuration::V2_MAX_PROMPT_LENGTH) if prompt

          body = { image: image }
          body[:prompt] = prompt if prompt
          body[:version] = version if version

          response = post(EXTRACT_ENDPOINT, body, params: breadcrumb_params(breadcrumb))
          LayoutResponse.new(status: response.status, headers: response.headers, body: response.body)
        end

        # Generates (or edits) a structured layout without rendering an image.
        #
        # @param prompt [String, nil] Description of the desired layout
        #   (max 4000 chars); at least one of +prompt+ or +references+ is required
        # @param references [Array<Hash>, nil] Up to 8 ordered compound
        #   references ({Configuration::V2_MAX_REFERENCES}); each entry may
        #   contain +image+ (a raw { data: }/{ ref: } image Hash), +layout+
        #   (a layout Hash), and/or +prompt+ (String) — at least one per entry
        # @param commands [Array<Hash>, nil] Ordered imperative layout edits;
        #   each entry is a Hash with an +op+ key (add, place, shift, remove,
        #   keep, change) plus op-specific fields
        # @param aspect_ratio [String, nil] Layout aspect ratio; v2 set
        #   ({Configuration::V2_ASPECT_RATIOS}), default "auto"
        # @param version [String, nil] Optional public model version alias
        # @param breadcrumb [String, nil] Request tracking value sent as the
        #   +breadcrumb+ query parameter; ignored by the API
        #
        # @return [LayoutResponse] Response containing the generated +layout+
        #
        # @raise [ValidationError] if neither prompt nor references is given,
        #   or any argument is malformed
        #
        # @example Free-form layout from a prompt
        #   result = client.v2.layouts.create(prompt: "a person at a cafe")
        #   result.layout[:regions] # => [{ label: "person", bbox: {...}, ... }]
        #
        # @note Experimental: layout generation commonly takes 10-40 seconds.
        def create(prompt: nil, references: nil, commands: nil, aspect_ratio: nil, version: nil, breadcrumb: nil)
          validate_prompt_or_references!(prompt, references)
          validate_prompt!(prompt, max_length: Configuration::V2_MAX_PROMPT_LENGTH) if prompt
          validate_compound_references!(references)
          validate_commands!(commands)
          validate_aspect_ratio!(aspect_ratio, Configuration::V2_ASPECT_RATIOS)

          body = build_create_body(prompt: prompt, references: references, commands: commands,
                                   aspect_ratio: aspect_ratio, version: version)

          response = post(CREATE_ENDPOINT, body, params: breadcrumb_params(breadcrumb))
          LayoutResponse.new(status: response.status, headers: response.headers, body: response.body)
        end

        # Renders a final image from a target layout.
        #
        # @param layout [Hash] The layout to render; must include a non-empty
        #   +regions+ Array (each region: +label+, +prompt+, +bbox+ with
        #   normalized x0/y0/x1/y1; optional +parent+, +region_type+,
        #   +image_index+, +image_region_index+)
        # @param references [Array<Hash>, nil] Up to 8 ordered compound
        #   references; same shape as {#create}
        # @param postprocessing [Array<Hash>, nil] Postprocessing steps, each
        #   with a +process+ key (e.g., { process: "fit_image", max_dim: 2048 })
        # @param version [String, nil] Optional public model version alias
        # @param accept [String, nil] Per-request Accept header: "image/png",
        #   "image/jpeg", or "image/webp" for a binary image response, or
        #   "application/json" (default)
        # @param breadcrumb [String, nil] Request tracking value sent as the
        #   +breadcrumb+ query parameter; ignored by the API
        #
        # @return [ImageResponse] Response containing the rendered image and
        #   the produced +layout+
        #
        # @raise [ValidationError] if layout is missing or malformed
        #
        # @example Render a layout to an image
        #   layout = { regions: [{ label: "cat", prompt: "a tabby cat",
        #                          bbox: { x0: 0.2, y0: 0.2, x1: 0.8, y1: 0.8 } }] }
        #   result = client.v2.layouts.render(layout: layout)
        #   File.binwrite("cat.png", Base64.decode64(result.image))
        #
        # @note Experimental: rendering commonly takes 40-80 seconds.
        def render(layout:, references: nil, postprocessing: nil, version: nil, accept: nil, breadcrumb: nil)
          validate_layout!(layout)
          validate_compound_references!(references)
          validate_postprocessing!(postprocessing)

          body = { layout: layout }
          body[:references] = references if references
          body[:postprocessing] = postprocessing if postprocessing
          body[:version] = version if version

          response = post(RENDER_ENDPOINT, body, params: breadcrumb_params(breadcrumb), accept: accept)
          ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
        end

        private

        # Builds the request body for the create_layout endpoint.
        #
        # @return [Hash] Request body with only the provided options
        # @api private
        def build_create_body(prompt:, references:, commands:, aspect_ratio:, version:)
          body = {}
          body[:prompt] = prompt if prompt
          body[:references] = references if references
          body[:commands] = commands if commands
          body[:aspect_ratio] = aspect_ratio if aspect_ratio
          body[:version] = version if version
          body
        end

        # Returns the query params Hash for a breadcrumb, or nil.
        #
        # @param breadcrumb [String, nil] Breadcrumb value
        # @return [Hash, nil] Query params
        # @api private
        def breadcrumb_params(breadcrumb)
          breadcrumb ? { breadcrumb: breadcrumb } : nil
        end

        # Reads a Hash value accepting symbol or string keys.
        #
        # @param hash [Hash] The Hash to read
        # @param key [Symbol] The key to look up (symbol or string form)
        # @return [Object, nil] The value, or nil when absent
        # @api private
        def fetch_value(hash, key)
          hash[key] || hash[key.to_s]
        end

        # Validates that at least one of prompt or references is present.
        #
        # @raise [ValidationError] if both are nil/empty
        # @api private
        def validate_prompt_or_references!(prompt, references)
          return if prompt && !prompt.empty?
          return if references && !references.empty?

          raise ValidationError, "At least one of prompt or references is required"
        end

        # Validates a raw image object ({ data: } or { ref: } shape).
        #
        # @param image [Object] The value to validate
        # @param label [String] Label for error messages
        # @raise [ValidationError] if not a Hash with exactly one non-empty
        #   String +data+ or +ref+ value
        # @api private
        def validate_raw_image!(image, label)
          raise ValidationError, "#{label} must be a Hash with exactly one of 'data' or 'ref'" unless image.is_a?(Hash)

          data = fetch_value(image, :data)
          ref = fetch_value(image, :ref)

          raise ValidationError, "#{label} must include exactly one of 'data' or 'ref'" if data.nil? == ref.nil?

          value = data || ref
          return if value.is_a?(String) && !value.empty?

          raise ValidationError, "#{label} '#{data ? "data" : "ref"}' must be a non-empty String"
        end

        # Validates compound layout references.
        #
        # @param references [Array<Hash>, nil] Compound reference entries
        # @raise [ValidationError] if not an Array of valid compound entries
        # @api private
        def validate_compound_references!(references)
          return if references.nil?

          unless references.is_a?(Array)
            raise ValidationError, "References must be an Array of compound reference Hashes"
          end

          max = Configuration::V2_MAX_REFERENCES
          raise ValidationError, "Maximum #{max} references allowed" if references.length > max

          references.each_with_index { |reference, index| validate_compound_reference!(reference, index) }
        end

        # Validates a single compound reference entry.
        #
        # @param reference [Hash] Entry with at least one of image/layout/prompt
        # @param index [Integer] Position in the references array
        # @raise [ValidationError] if the entry carries none of the allowed
        #   fields, or carries a malformed image/layout
        # @api private
        def validate_compound_reference!(reference, index)
          raise ValidationError, "Reference at index #{index} must be a Hash" unless reference.is_a?(Hash)

          image = fetch_value(reference, :image)
          layout = fetch_value(reference, :layout)
          prompt = fetch_value(reference, :prompt)

          if image.nil? && layout.nil? && prompt.nil?
            raise ValidationError,
                  "Reference at index #{index} must include at least one of 'image', 'layout', 'prompt'"
          end

          validate_raw_image!(image, "Reference at index #{index} 'image'") if image
          validate_reference_layout!(layout, index)
        end

        # Validates the layout value inside a compound reference.
        #
        # @param layout [Object] The value to check
        # @param index [Integer] Position in the references array
        # @raise [ValidationError] if present and not a Hash
        # @api private
        def validate_reference_layout!(layout, index)
          return if layout.nil? || layout.is_a?(Hash)

          raise ValidationError, "Reference at index #{index} 'layout' must be a Hash"
        end

        # Validates the target layout for rendering.
        #
        # @param layout [Object] The layout to validate
        # @raise [ValidationError] if not a Hash with a non-empty regions Array
        # @api private
        def validate_layout!(layout)
          regions = fetch_value(layout, :regions) if layout.is_a?(Hash)
          return if regions.is_a?(Array) && !regions.empty?

          raise ValidationError, "Layout must be a Hash with a non-empty 'regions' Array"
        end

        # Validates layout commands.
        #
        # @param commands [Array<Hash>, nil] Command entries
        # @raise [ValidationError] if not an Array of Hashes with an +op+ key
        # @api private
        def validate_commands!(commands)
          return if commands.nil?
          raise ValidationError, "Commands must be an Array of Hashes with an 'op' key" unless commands.is_a?(Array)

          commands.each_with_index do |command, index|
            next if command.is_a?(Hash) && (command.key?(:op) || command.key?("op"))

            raise ValidationError, "Command at index #{index} must be a Hash with an 'op' key"
          end
        end
      end
    end
  end
end

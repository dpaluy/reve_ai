# frozen_string_literal: true

module ReveAI
  # API resource classes.
  #
  # Each resource class provides methods for a related set of API operations.
  module Resources
    # Base class for API resources with common validation methods.
    #
    # Provides HTTP client access and input validation for all resource classes.
    #
    # @abstract Subclass and implement endpoint-specific methods
    # @api private
    class Base
      # @return [Client] The client instance for this resource
      attr_reader :client

      # Creates a new resource instance.
      #
      # @param client [Client] The API client
      # @api private
      def initialize(client)
        @client = client
      end

      protected

      # Returns the HTTP client for making requests.
      #
      # @return [HTTP::Client] HTTP client instance
      # @api private
      def http_client
        client.http_client
      end

      # Returns the client configuration.
      #
      # @return [Configuration] Configuration instance
      # @api private
      def configuration
        client.configuration
      end

      # Makes a GET request to the API.
      #
      # @param path [String] API endpoint path
      # @param params [Hash, nil] Query parameters to merge into the URL
      # @return [Response] API response
      # @api private
      def get(path, params: nil)
        http_client.get(path, params: params)
      end

      # Makes a POST request to the API.
      #
      # @param path [String] API endpoint path
      # @param body [Hash] Request body
      # @param params [Hash, nil] Query parameters to merge into the URL
      #   (e.g., { breadcrumb: "my-tracking-value" })
      # @param accept [String, nil] Per-request Accept header override
      #   (e.g., "image/webp")
      # @return [Response] API response
      # @api private
      def post(path, body = {}, params: nil, accept: nil)
        http_client.post(path, body, params: params, accept: accept)
      end

      # Validates a text prompt.
      #
      # @param prompt [String] The prompt to validate
      # @param field_name [String] Name for error messages (default: "Prompt")
      # @param max_length [Integer] Maximum allowed length in characters
      #   (default: v1 limit of {Configuration::MAX_PROMPT_LENGTH})
      # @raise [ValidationError] if prompt is nil, empty, or exceeds max length
      # @api private
      def validate_prompt!(prompt, field_name: "Prompt", max_length: Configuration::MAX_PROMPT_LENGTH)
        raise ValidationError, "#{field_name} is required" if prompt.nil? || prompt.empty?

        return unless prompt.length > max_length

        raise ValidationError, "#{field_name} exceeds maximum length of #{max_length} characters"
      end

      # Validates an aspect ratio value.
      #
      # @param aspect_ratio [String, nil] The aspect ratio to validate
      # @param valid_ratios [Array<String>] Allowed aspect ratios
      #   (default: v1 set {Configuration::VALID_ASPECT_RATIOS})
      # @raise [ValidationError] if aspect ratio is invalid
      # @api private
      def validate_aspect_ratio!(aspect_ratio, valid_ratios = Configuration::VALID_ASPECT_RATIOS)
        return if aspect_ratio.nil?
        return if valid_ratios.include?(aspect_ratio)

        raise ValidationError, "Invalid aspect_ratio '#{aspect_ratio}'. Must be one of: #{valid_ratios.join(", ")}"
      end

      # Validates a postprocessing steps array.
      #
      # @param postprocessing [Array<Hash>, nil] Postprocessing steps, each
      #   requiring a +process+ key (e.g., { process: "upscale", upscale_factor: 2 })
      # @raise [ValidationError] if not an Array of Hashes, or a step lacks a +process+ key
      # @api private
      def validate_postprocessing!(postprocessing)
        return if postprocessing.nil?

        unless postprocessing_steps?(postprocessing)
          raise ValidationError, "Postprocessing must be an Array of Hashes with a 'process' key"
        end

        postprocessing.each_with_index do |step, index|
          next if step.key?(:process) || step.key?("process")

          raise ValidationError, "Postprocessing step at index #{index} must include a 'process' key"
        end
      end

      # Checks whether a value is an Array of Hashes (postprocessing shape).
      #
      # @param value [Object] The value to check
      # @return [Boolean] true if value is an Array of Hashes
      # @api private
      def postprocessing_steps?(value)
        value.is_a?(Array) && value.all?(Hash)
      end

      # Validates a test_time_scaling value.
      #
      # @param value [Numeric, nil] Scaling factor (1-15)
      # @raise [ValidationError] if not a Numeric between 1 and 15
      # @api private
      def validate_test_time_scaling!(value)
        return if value.nil?
        return if value.is_a?(Numeric) && value.between?(1, 15)

        raise ValidationError, "test_time_scaling must be a number between 1 and 15"
      end

      # Validates a single reference image.
      #
      # @param image [String] Base64 encoded image data
      # @raise [ValidationError] if image is nil or empty
      # @api private
      def validate_reference_image!(image)
        raise ValidationError, "Reference image is required" if image.nil? || image.empty?
      end

      # Validates an array of reference images.
      #
      # @param images [Array<String>] Array of base64 encoded images
      # @raise [ValidationError] if images is nil, empty, exceeds max, or contains empty elements
      # @api private
      def validate_reference_images!(images)
        raise ValidationError, "Reference images are required" if images.nil? || images.empty?

        max_images = Configuration::MAX_REFERENCE_IMAGES
        raise ValidationError, "Maximum #{max_images} reference images allowed" if images.length > max_images

        images.each_with_index do |image, index|
          raise ValidationError, "Reference image at index #{index} is empty" if image.nil? || image.empty?
        end
      end
    end
  end
end

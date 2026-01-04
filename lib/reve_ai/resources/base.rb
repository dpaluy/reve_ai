# frozen_string_literal: true

module ReveAI
  # API resource classes
  module Resources
    # Base class for API resources with common validation methods
    class Base
      attr_reader :client

      def initialize(client)
        @client = client
      end

      protected

      def http_client
        client.http_client
      end

      def configuration
        client.configuration
      end

      def post(path, body = {})
        http_client.post(path, body)
      end

      def validate_prompt!(prompt, field_name: "Prompt")
        raise ValidationError, "#{field_name} is required" if prompt.nil? || prompt.empty?

        max_length = Configuration::MAX_PROMPT_LENGTH
        return unless prompt.length > max_length

        raise ValidationError, "#{field_name} exceeds maximum length of #{max_length} characters"
      end

      def validate_aspect_ratio!(aspect_ratio)
        return if aspect_ratio.nil?

        valid_ratios = Configuration::VALID_ASPECT_RATIOS
        return if valid_ratios.include?(aspect_ratio)

        raise ValidationError, "Invalid aspect_ratio '#{aspect_ratio}'. Must be one of: #{valid_ratios.join(", ")}"
      end

      def validate_reference_image!(image)
        raise ValidationError, "Reference image is required" if image.nil? || image.empty?
      end

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

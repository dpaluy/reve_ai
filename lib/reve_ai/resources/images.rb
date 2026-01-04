# frozen_string_literal: true

module ReveAI
  module Resources
    # Image generation, editing, and remixing operations
    class Images < Base
      CREATE_ENDPOINT = "/v1/image/create"
      EDIT_ENDPOINT = "/v1/image/edit"
      REMIX_ENDPOINT = "/v1/image/remix"

      # Generate an image from a text prompt
      # @param prompt [String] Text description of the desired image (max 2560 chars)
      # @param aspect_ratio [String] One of: 16:9, 9:16, 3:2, 2:3, 4:3, 3:4, 1:1 (default: 3:2)
      # @param version [String] Model version: "latest" or "reve-create@20250915" (default: latest)
      def create(prompt:, aspect_ratio: nil, version: nil)
        validate_prompt!(prompt)
        validate_aspect_ratio!(aspect_ratio)

        body = { prompt: prompt }
        body[:aspect_ratio] = aspect_ratio if aspect_ratio
        body[:version] = version if version

        response = post(CREATE_ENDPOINT, body)
        ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
      end

      # Edit an existing image using text instructions
      # @param edit_instruction [String] Text description of how to edit the image (max 2560 chars)
      # @param reference_image [String] Base64 encoded image to edit
      # @param aspect_ratio [String] One of: 16:9, 9:16, 3:2, 2:3, 4:3, 3:4, 1:1 (default: reference image ratio)
      # @param version [String] Model version (default: latest)
      def edit(edit_instruction:, reference_image:, aspect_ratio: nil, version: nil)
        validate_prompt!(edit_instruction, field_name: "Edit instruction")
        validate_reference_image!(reference_image)

        body = { edit_instruction: edit_instruction, reference_image: reference_image }
        body[:aspect_ratio] = aspect_ratio if aspect_ratio
        body[:version] = version if version

        response = post(EDIT_ENDPOINT, body)
        ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
      end

      # Create images from text and reference images
      # @param prompt [String] Text description, can include <img>N</img> tags (max 2560 chars)
      # @param reference_images [Array<String>] Array of base64 encoded images (1-6 images)
      # @param aspect_ratio [String] One of: 16:9, 9:16, 3:2, 2:3, 4:3, 3:4, 1:1 (default: model's choice)
      # @param version [String] Model version (default: latest)
      def remix(prompt:, reference_images:, aspect_ratio: nil, version: nil)
        validate_prompt!(prompt)
        validate_reference_images!(reference_images)
        validate_aspect_ratio!(aspect_ratio)

        body = { prompt: prompt, reference_images: reference_images }
        body[:aspect_ratio] = aspect_ratio if aspect_ratio
        body[:version] = version if version

        response = post(REMIX_ENDPOINT, body)
        ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
      end
    end
  end
end

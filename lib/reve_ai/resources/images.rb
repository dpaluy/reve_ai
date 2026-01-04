# frozen_string_literal: true

module ReveAI
  module Resources
    # Image generation, editing, and remixing operations.
    #
    # Provides methods for creating images from text prompts, editing existing
    # images, and remixing multiple reference images into new compositions.
    #
    # @example Generate an image from text
    #   client = ReveAI::Client.new(api_key: "your-key")
    #   result = client.images.create(
    #     prompt: "A sunset over mountains with a lake in the foreground",
    #     aspect_ratio: "16:9"
    #   )
    #   puts result.base64 # Base64 encoded PNG
    #
    # @example Edit an existing image
    #   result = client.images.edit(
    #     edit_instruction: "Make the sky more dramatic with storm clouds",
    #     reference_image: base64_encoded_original
    #   )
    #
    # @example Remix multiple images
    #   result = client.images.remix(
    #     prompt: "Combine the style of <img>1</img> with the subject of <img>2</img>",
    #     reference_images: [style_image_base64, subject_image_base64]
    #   )
    #
    # @note All images are returned as base64 encoded PNG data.
    # @see https://api.reve.com/console/docs Reve API Documentation
    class Images < Base
      # @return [String] API endpoint for image creation
      CREATE_ENDPOINT = "/v1/image/create"

      # @return [String] API endpoint for image editing
      EDIT_ENDPOINT = "/v1/image/edit"

      # @return [String] API endpoint for image remixing
      REMIX_ENDPOINT = "/v1/image/remix"

      # Generates an image from a text prompt.
      #
      # @param prompt [String] Text description of the desired image (max 2560 chars)
      # @param aspect_ratio [String, nil] Output aspect ratio (defaults to API default)
      # @param version [String, nil] Model version to use (defaults to "latest")
      #
      # @option aspect_ratio [String] "16:9" Widescreen landscape
      # @option aspect_ratio [String] "9:16" Portrait (phone)
      # @option aspect_ratio [String] "3:2" Classic landscape
      # @option aspect_ratio [String] "2:3" Classic portrait
      # @option aspect_ratio [String] "4:3" Standard landscape
      # @option aspect_ratio [String] "3:4" Standard portrait
      # @option aspect_ratio [String] "1:1" Square
      #
      # @return [ImageResponse] Response containing base64 encoded image
      #
      # @raise [ValidationError] if prompt is empty or exceeds max length
      # @raise [ValidationError] if aspect_ratio is invalid
      # @raise [BadRequestError] if API rejects the request
      # @raise [UnauthorizedError] if API key is invalid
      # @raise [InsufficientCreditsError] if account has no credits
      # @raise [RateLimitError] if rate limit is exceeded
      #
      # @example Basic usage
      #   result = client.images.create(prompt: "A cat wearing a top hat")
      #
      # @example With aspect ratio
      #   result = client.images.create(
      #     prompt: "A panoramic mountain landscape",
      #     aspect_ratio: "16:9"
      #   )
      #
      # @example Save to file
      #   result = client.images.create(prompt: "A sunset")
      #   File.binwrite("image.png", Base64.decode64(result.base64))
      #
      # @see https://api.reve.com/console/docs#/Image/create_v1_image_create_post
      def create(prompt:, aspect_ratio: nil, version: nil)
        validate_prompt!(prompt)
        validate_aspect_ratio!(aspect_ratio)

        body = { prompt: prompt }
        body[:aspect_ratio] = aspect_ratio if aspect_ratio
        body[:version] = version if version

        response = post(CREATE_ENDPOINT, body)
        ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
      end

      # Edits an existing image using text instructions.
      #
      # @param edit_instruction [String] Text description of how to edit the image (max 2560 chars)
      # @param reference_image [String] Base64 encoded image to edit
      # @param aspect_ratio [String, nil] Output aspect ratio (defaults to reference image ratio)
      # @param version [String, nil] Model version to use (defaults to "latest")
      #
      # @return [ImageResponse] Response containing base64 encoded edited image
      #
      # @raise [ValidationError] if edit_instruction is empty or exceeds max length
      # @raise [ValidationError] if reference_image is empty
      # @raise [ValidationError] if aspect_ratio is invalid
      # @raise [UnprocessableEntityError] if reference_image is not valid base64
      # @raise [BadRequestError] if API rejects the request
      # @raise [UnauthorizedError] if API key is invalid
      #
      # @example Change colors
      #   result = client.images.edit(
      #     edit_instruction: "Change the car color from red to blue",
      #     reference_image: original_image_base64
      #   )
      #
      # @example Add elements
      #   result = client.images.edit(
      #     edit_instruction: "Add a rainbow in the sky",
      #     reference_image: landscape_base64
      #   )
      #
      # @see https://api.reve.com/console/docs#/Image/edit_v1_image_edit_post
      def edit(edit_instruction:, reference_image:, aspect_ratio: nil, version: nil)
        validate_prompt!(edit_instruction, field_name: "Edit instruction")
        validate_reference_image!(reference_image)

        body = { edit_instruction: edit_instruction, reference_image: reference_image }
        body[:aspect_ratio] = aspect_ratio if aspect_ratio
        body[:version] = version if version

        response = post(EDIT_ENDPOINT, body)
        ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
      end

      # Creates a new image by remixing multiple reference images.
      #
      # Use `<img>N</img>` tags in the prompt to reference specific images,
      # where N is the 1-based index into the reference_images array.
      #
      # @param prompt [String] Text description with optional image references (max 2560 chars)
      # @param reference_images [Array<String>] Array of base64 encoded images (1-6 images)
      # @param aspect_ratio [String, nil] Output aspect ratio (defaults to model's choice)
      # @param version [String, nil] Model version to use (defaults to "latest")
      #
      # @return [ImageResponse] Response containing base64 encoded remixed image
      #
      # @raise [ValidationError] if prompt is empty or exceeds max length
      # @raise [ValidationError] if reference_images is empty or exceeds 6 images
      # @raise [ValidationError] if any reference image is empty
      # @raise [ValidationError] if aspect_ratio is invalid
      # @raise [BadRequestError] if API rejects the request
      #
      # @example Combine two images
      #   result = client.images.remix(
      #     prompt: "Combine the landscape from <img>1</img> with the sky from <img>2</img>",
      #     reference_images: [landscape_base64, sky_base64]
      #   )
      #
      # @example Style transfer
      #   result = client.images.remix(
      #     prompt: "Apply the artistic style of <img>1</img> to the photo <img>2</img>",
      #     reference_images: [artwork_base64, photo_base64]
      #   )
      #
      # @example Multiple references
      #   result = client.images.remix(
      #     prompt: "Create a scene with the dog from <img>1</img>, " \
      #             "the background from <img>2</img>, and lighting from <img>3</img>",
      #     reference_images: [dog_base64, background_base64, lighting_ref_base64]
      #   )
      #
      # @see https://api.reve.com/console/docs#/Image/remix_v1_image_remix_post
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

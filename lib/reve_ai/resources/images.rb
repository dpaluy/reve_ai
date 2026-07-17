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
    #     prompt: "Combine the style of <img>0</img> with the subject of <img>1</img>",
    #     reference_images: [style_image_base64, subject_image_base64]
    #   )
    #
    # @note By default all images are returned as base64 encoded PNG data;
    #   pass accept: "image/png", "image/jpeg", or "image/webp" to any method
    #   for raw image bytes instead (see method docs).
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
      # @param postprocessing [Array<Hash>, nil] Postprocessing steps applied after
      #   generation; each step requires a +process+ key:
      #   +upscale+ (+upscale_factor+ 2-4, adds credits cost),
      #   +remove_background+,
      #   +fit_image+ (+max_dim+/+max_width+/+max_height+, max 4096, free),
      #   +effect+ (+effect_name+, optional +effect_parameters+ overrides nested
      #   as +{ filter_id: { uniform_id: value } }+)
      # @param test_time_scaling [Numeric, nil] Effort scaling factor 1-15
      #   (default 1); values above 1 add credits cost, values above 5 only
      #   occasionally improve results
      # @param accept [String, nil] Response format: "application/json" (default)
      #   or "image/png", "image/jpeg", "image/webp" for raw image bytes, e.g.
      #   accept: "image/webp" returns the raw image via result.image (metadata
      #   moves to the X-Reve-* response headers)
      # @param breadcrumb [String, nil] Request tracking label sent as the
      #   +breadcrumb+ query param; ignored by the API, searchable in the Usage page
      #
      # @option aspect_ratio [String] "16:9" Widescreen landscape
      # @option aspect_ratio [String] "9:16" Portrait (phone)
      # @option aspect_ratio [String] "3:2" Classic landscape
      # @option aspect_ratio [String] "2:3" Classic portrait
      # @option aspect_ratio [String] "4:3" Standard landscape
      # @option aspect_ratio [String] "3:4" Standard portrait
      # @option aspect_ratio [String] "1:1" Square
      #
      # @return [ImageResponse] Response containing base64 encoded image,
      #   or raw image bytes when +accept+ is an image format
      #
      # @raise [ValidationError] if prompt is empty or exceeds max length
      # @raise [ValidationError] if aspect_ratio is invalid
      # @raise [ValidationError] if postprocessing is not an Array of Hashes with a +process+ key
      # @raise [ValidationError] if test_time_scaling is not a number between 1 and 15
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
      # @example With postprocessing (upscale, then fit within 2048px)
      #   result = client.images.create(
      #     prompt: "A panoramic mountain landscape",
      #     postprocessing: [{ process: "upscale", upscale_factor: 2 },
      #                      { process: "fit_image", max_dim: 2048 }]
      #   )
      #
      # @example Request raw WebP bytes instead of JSON
      #   result = client.images.create(prompt: "A sunset", accept: "image/webp")
      #   File.binwrite("sunset.webp", result.image) # raw bytes, no Base64 decode
      #
      # @example Save to file
      #   result = client.images.create(prompt: "A sunset")
      #   File.binwrite("image.png", Base64.decode64(result.base64))
      #
      # @see https://api.reve.com/console/docs#/Image/create_v1_image_create_post
      def create(prompt:, aspect_ratio: nil, version: nil, postprocessing: nil, test_time_scaling: nil,
                 accept: nil, breadcrumb: nil)
        validate_prompt!(prompt)
        validate_aspect_ratio!(aspect_ratio)
        validate_postprocessing!(postprocessing)
        validate_test_time_scaling!(test_time_scaling)

        body = { prompt: prompt }
        body[:aspect_ratio] = aspect_ratio if aspect_ratio
        body[:version] = version if version
        body[:postprocessing] = postprocessing if postprocessing
        body[:test_time_scaling] = test_time_scaling if test_time_scaling

        params = breadcrumb ? { breadcrumb: breadcrumb } : nil

        response = post(CREATE_ENDPOINT, body, params: params, accept: accept)
        ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
      end

      # Edits an existing image using text instructions.
      #
      # @param edit_instruction [String] Text description of how to edit the image (max 2560 chars)
      # @param reference_image [String] Base64 encoded image to edit
      # @param aspect_ratio [String, nil] Output aspect ratio (defaults to reference image ratio)
      # @param version [String, nil] Model version to use (defaults to "latest")
      # @param postprocessing [Array<Hash>, nil] Postprocessing steps applied after
      #   generation; see {#create} for the supported step shapes
      # @param test_time_scaling [Numeric, nil] Effort scaling factor 1-15
      #   (default 1); values above 1 add credits cost
      # @param accept [String, nil] Response format: "application/json" (default)
      #   or "image/png", "image/jpeg", "image/webp" for raw image bytes via
      #   result.image (metadata moves to the X-Reve-* response headers)
      # @param breadcrumb [String, nil] Request tracking label sent as the
      #   +breadcrumb+ query param; ignored by the API, searchable in the Usage page
      #
      # @return [ImageResponse] Response containing base64 encoded edited image,
      #   or raw image bytes when +accept+ is an image format
      #
      # @raise [ValidationError] if edit_instruction is empty or exceeds max length
      # @raise [ValidationError] if reference_image is empty
      # @raise [ValidationError] if aspect_ratio is invalid
      # @raise [ValidationError] if postprocessing is not an Array of Hashes with a +process+ key
      # @raise [ValidationError] if test_time_scaling is not a number between 1 and 15
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
      # @example Remove the background after editing
      #   result = client.images.edit(
      #     edit_instruction: "Change the car color from red to blue",
      #     reference_image: original_image_base64,
      #     postprocessing: [{ process: "remove_background" }]
      #   )
      #
      # @see https://api.reve.com/console/docs#/Image/edit_v1_image_edit_post
      def edit(edit_instruction:, reference_image:, aspect_ratio: nil, version: nil, postprocessing: nil,
               test_time_scaling: nil, accept: nil, breadcrumb: nil)
        validate_prompt!(edit_instruction, field_name: "Edit instruction")
        validate_reference_image!(reference_image)
        validate_postprocessing!(postprocessing)
        validate_test_time_scaling!(test_time_scaling)

        body = { edit_instruction: edit_instruction, reference_image: reference_image }
        body[:aspect_ratio] = aspect_ratio if aspect_ratio
        body[:version] = version if version
        body[:postprocessing] = postprocessing if postprocessing
        body[:test_time_scaling] = test_time_scaling if test_time_scaling

        params = breadcrumb ? { breadcrumb: breadcrumb } : nil

        response = post(EDIT_ENDPOINT, body, params: params, accept: accept)
        ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
      end

      # Creates a new image by remixing multiple reference images.
      #
      # Use `<img>N</img>` tags in the prompt to reference specific images,
      # where N is the 0-based index into the reference_images array.
      #
      # @param prompt [String] Text description with optional image references (max 2560 chars)
      # @param reference_images [Array<String>] Array of base64 encoded images (1-6 images)
      # @param aspect_ratio [String, nil] Output aspect ratio (defaults to model's choice)
      # @param version [String, nil] Model version to use (defaults to "latest")
      # @param postprocessing [Array<Hash>, nil] Postprocessing steps applied after
      #   generation; see {#create} for the supported step shapes
      # @param test_time_scaling [Numeric, nil] Effort scaling factor 1-15
      #   (default 1); values above 1 add credits cost
      # @param accept [String, nil] Response format: "application/json" (default)
      #   or "image/png", "image/jpeg", "image/webp" for raw image bytes via
      #   result.image (metadata moves to the X-Reve-* response headers)
      # @param breadcrumb [String, nil] Request tracking label sent as the
      #   +breadcrumb+ query param; ignored by the API, searchable in the Usage page
      #
      # @return [ImageResponse] Response containing base64 encoded remixed image,
      #   or raw image bytes when +accept+ is an image format
      #
      # @raise [ValidationError] if prompt is empty or exceeds max length
      # @raise [ValidationError] if reference_images is empty or exceeds 6 images
      # @raise [ValidationError] if any reference image is empty
      # @raise [ValidationError] if aspect_ratio is invalid
      # @raise [ValidationError] if postprocessing is not an Array of Hashes with a +process+ key
      # @raise [ValidationError] if test_time_scaling is not a number between 1 and 15
      # @raise [BadRequestError] if API rejects the request
      #
      # @example Combine two images
      #   result = client.images.remix(
      #     prompt: "Combine the landscape from <img>0</img> with the sky from <img>1</img>",
      #     reference_images: [landscape_base64, sky_base64]
      #   )
      #
      # @example Style transfer
      #   result = client.images.remix(
      #     prompt: "Apply the artistic style of <img>0</img> to the photo <img>1</img>",
      #     reference_images: [artwork_base64, photo_base64]
      #   )
      #
      # @example Multiple references
      #   result = client.images.remix(
      #     prompt: "Create a scene with the dog from <img>0</img>, " \
      #             "the background from <img>1</img>, and lighting from <img>2</img>",
      #     reference_images: [dog_base64, background_base64, lighting_ref_base64]
      #   )
      #
      # @see https://api.reve.com/console/docs#/Image/remix_v1_image_remix_post
      def remix(prompt:, reference_images:, aspect_ratio: nil, version: nil, postprocessing: nil,
                test_time_scaling: nil, accept: nil, breadcrumb: nil)
        validate_prompt!(prompt)
        validate_reference_images!(reference_images)
        validate_aspect_ratio!(aspect_ratio)
        validate_postprocessing!(postprocessing)
        validate_test_time_scaling!(test_time_scaling)

        body = { prompt: prompt, reference_images: reference_images }
        body[:aspect_ratio] = aspect_ratio if aspect_ratio
        body[:version] = version if version
        body[:postprocessing] = postprocessing if postprocessing
        body[:test_time_scaling] = test_time_scaling if test_time_scaling

        params = breadcrumb ? { breadcrumb: breadcrumb } : nil

        response = post(REMIX_ENDPOINT, body, params: params, accept: accept)
        ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
      end
    end
  end
end

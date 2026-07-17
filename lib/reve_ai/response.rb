# frozen_string_literal: true

module ReveAI
  # Base response wrapper for API responses.
  #
  # Provides access to HTTP status, headers, and response body. The body is a
  # parsed Hash for JSON responses, or the raw image String (bytes) when the
  # API answers with a binary body (Accept: image/*); in that case all
  # metadata is carried by the X-Reve-* response headers.
  #
  # @see ImageResponse
  # @see LayoutResponse
  class Response
    # @return [Integer] HTTP status code
    attr_reader :status

    # @return [Hash] Response headers
    attr_reader :headers

    # @return [Hash, String] Parsed response body, or raw bytes String
    #   for binary (image/*) responses
    attr_reader :body

    # Creates a new response wrapper.
    #
    # @param status [Integer] HTTP status code
    # @param headers [Hash] Response headers
    # @param body [Hash, String] Parsed response body, or raw bytes String
    def initialize(status:, headers:, body:)
      @status = status
      @headers = headers
      @body = body
    end

    # Checks if the response indicates success (2xx status).
    #
    # @return [Boolean] true if status is between 200 and 299
    def success?
      status >= 200 && status < 300
    end

    # Checks if the response body is raw binary data (e.g., image bytes).
    #
    # @return [Boolean] true if body is not a parsed JSON Hash
    def binary?
      !body.is_a?(Hash)
    end

    # Returns the request ID for this response.
    #
    # Useful for debugging and support requests.
    #
    # @return [String, nil] Request ID from body or headers
    def request_id
      body_value(:request_id) || headers["x-reve-request-id"]
    end

    private

    # Reads a key from the body when it is a Hash (JSON response).
    #
    # Binary (String) bodies have no keys; header fallbacks apply instead.
    #
    # @param key [Symbol] Body key to read
    # @return [Object, nil] Body value, or nil for binary bodies
    # @api private
    def body_value(key)
      body[key] if body.is_a?(Hash)
    end
  end

  # Response wrapper for image generation API responses.
  #
  # Provides convenient accessors for image data, version info,
  # content policy status, and credit usage. All accessors work for both
  # JSON responses (values from the parsed body) and binary responses
  # (values from the X-Reve-* headers).
  #
  # @example Accessing image data
  #   result = client.images.create(prompt: "A sunset")
  #   png_data = Base64.decode64(result.base64)
  #   File.binwrite("image.png", png_data)
  #
  # @example Checking content policy
  #   result = client.images.create(prompt: "...")
  #   if result.content_violation?
  #     puts "Content policy violated"
  #   end
  #
  # @example Tracking credit usage
  #   result = client.images.create(prompt: "A cat")
  #   puts "Used #{result.credits_used} credits, #{result.credits_remaining} remaining"
  #
  # @see Response
  class ImageResponse < Response
    # Returns the image data.
    #
    # For JSON responses this is the base64 encoded image; for binary
    # responses (Accept: image/*) it is the raw image bytes in the
    # negotiated format, ready to write to disk without decoding.
    #
    # @return [String, nil] Base64 encoded image data (JSON response) or
    #   raw image bytes (binary response)
    #
    # @example Save a JSON (base64) response to file
    #   require "base64"
    #   File.binwrite("output.png", Base64.decode64(result.image))
    #
    # @example Save a binary response to file (no Base64 decode needed)
    #   File.binwrite("output.webp", result.image)
    def image
      binary? ? body : body[:image]
    end

    # Alias for {#image}.
    #
    # @note Despite the name, binary responses (Accept: image/*) return raw
    #   image bytes here, not base64 data.
    #
    # @return [String, nil] Base64 encoded image data (JSON response) or
    #   raw image bytes (binary response)
    # @see #image
    def base64
      image
    end

    # Returns the layout object for this generation.
    #
    # Present on v2 create/render JSON responses; nil on v1 responses and
    # on binary (Accept: image/*) responses.
    #
    # @return [Hash, nil] Layout Hash (e.g., +prompt+, +regions+, +width+,
    #   +height+), or nil when absent
    def layout
      body_value(:layout)
    end

    # Returns the model version used for generation.
    #
    # @return [String, nil] Model version (e.g., "reve-create@20250915")
    #
    # @example
    #   result.version # => "reve-create@20250915"
    def version
      body_value(:version) || headers["x-reve-version"]
    end

    # Checks if the generated image violates content policy.
    #
    # @return [Boolean] true if content policy was violated
    #
    # @example
    #   if result.content_violation?
    #     puts "Warning: Content policy violated"
    #   end
    def content_violation?
      body_value(:content_violation) == true ||
        headers["x-reve-content-violation"] == "true"
    end

    # Returns the number of credits used for this request.
    #
    # @return [Integer, nil] Credits consumed by this generation
    #
    # @example
    #   puts "This request used #{result.credits_used} credits"
    def credits_used
      body_value(:credits_used) || headers["x-reve-credits-used"]&.to_i
    end

    # Returns the number of credits remaining after this request.
    #
    # @return [Integer, nil] Remaining credit balance
    #
    # @example
    #   if result.credits_remaining < 100
    #     puts "Warning: Low credit balance"
    #   end
    def credits_remaining
      body_value(:credits_remaining) || headers["x-reve-credits-remaining"]&.to_i
    end
  end

  # Response wrapper for layout-only API responses.
  #
  # Returned by the v2 extract_layout and create_layout endpoints, which
  # produce a layout object but no image. Accessors fall back to the
  # X-Reve-* headers when the body carries no value.
  #
  # @example Inspecting a layout
  #   result = client.v2.layouts.extract(image: base64_image)
  #   result.layout # => { prompt: "...", regions: [...], width: 4096, height: 2560 }
  #
  # @see Response
  # @see ImageResponse
  class LayoutResponse < Response
    # Returns the layout object.
    #
    # @return [Hash, nil] Layout Hash (e.g., +prompt+, +regions+, +width+,
    #   +height+), or nil when absent
    def layout
      body_value(:layout)
    end

    # Checks if the request violates content policy.
    #
    # @return [Boolean] true if content policy was violated
    def content_violation?
      body_value(:content_violation) == true ||
        headers["x-reve-content-violation"] == "true"
    end

    # Returns the number of credits used for this request.
    #
    # @return [Integer, nil] Credits consumed by this request
    def credits_used
      body_value(:credits_used) || headers["x-reve-credits-used"]&.to_i
    end

    # Returns the number of credits remaining after this request.
    #
    # @return [Integer, nil] Remaining credit balance
    def credits_remaining
      body_value(:credits_remaining) || headers["x-reve-credits-remaining"]&.to_i
    end
  end
end

# frozen_string_literal: true

module ReveAI
  # Base response wrapper for API responses.
  #
  # Provides access to HTTP status, headers, and parsed response body.
  #
  # @see ImageResponse
  class Response
    # @return [Integer] HTTP status code
    attr_reader :status

    # @return [Hash] Response headers
    attr_reader :headers

    # @return [Hash] Parsed response body
    attr_reader :body

    # Creates a new response wrapper.
    #
    # @param status [Integer] HTTP status code
    # @param headers [Hash] Response headers
    # @param body [Hash] Parsed response body
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

    # Returns the request ID for this response.
    #
    # Useful for debugging and support requests.
    #
    # @return [String, nil] Request ID from body or headers
    def request_id
      body[:request_id] || headers["x-reve-request-id"]
    end
  end

  # Response wrapper for image generation API responses.
  #
  # Provides convenient accessors for image data, version info,
  # content policy status, and credit usage.
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
    # Returns the base64 encoded image data.
    #
    # The image is in PNG format. Use Base64.decode64 to get raw bytes.
    #
    # @return [String, nil] Base64 encoded PNG image data
    #
    # @example Save to file
    #   require "base64"
    #   png_bytes = Base64.decode64(result.image)
    #   File.binwrite("output.png", png_bytes)
    def image
      body[:image]
    end

    # Alias for {#image}.
    #
    # @return [String, nil] Base64 encoded PNG image data
    # @see #image
    def base64
      image
    end

    # Returns the model version used for generation.
    #
    # @return [String, nil] Model version (e.g., "reve-create@20250915")
    #
    # @example
    #   result.version # => "reve-create@20250915"
    def version
      body[:version] || headers["x-reve-version"]
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
      body[:content_violation] == true ||
        headers["x-reve-content-violation"] == "true"
    end

    # Returns the number of credits used for this request.
    #
    # @return [Integer, nil] Credits consumed by this generation
    #
    # @example
    #   puts "This request used #{result.credits_used} credits"
    def credits_used
      body[:credits_used] || headers["x-reve-credits-used"]&.to_i
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
      body[:credits_remaining] || headers["x-reve-credits-remaining"]&.to_i
    end
  end
end

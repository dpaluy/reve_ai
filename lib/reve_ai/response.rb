# frozen_string_literal: true

module ReveAI
  # Base response wrapper for API responses
  class Response
    attr_reader :status, :headers, :body

    def initialize(status:, headers:, body:)
      @status = status
      @headers = headers
      @body = body
    end

    def success?
      status >= 200 && status < 300
    end

    def request_id
      body[:request_id] || headers["x-reve-request-id"]
    end
  end

  # Response wrapper for image generation API responses
  class ImageResponse < Response
    # Base64 encoded image data (PNG format)
    def image
      body[:image]
    end

    # Alias for image
    def base64
      image
    end

    # Model version used for generation (e.g., "reve-create@20250915")
    def version
      body[:version] || headers["x-reve-version"]
    end

    # Whether the generated image violates content policy
    def content_violation?
      body[:content_violation] == true ||
        headers["x-reve-content-violation"] == "true"
    end

    # Number of credits used for this request
    def credits_used
      body[:credits_used] || headers["x-reve-credits-used"]&.to_i
    end

    # Number of credits remaining after this request
    def credits_remaining
      body[:credits_remaining] || headers["x-reve-credits-remaining"]&.to_i
    end
  end
end

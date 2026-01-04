# ReveAI

Ruby client for the [Reve image generation API](https://api.reve.com/console/docs).

[![Gem Version](https://badge.fury.io/rb/reve_ai.svg)](https://badge.fury.io/rb/reve_ai)
[![ci](https://github.com/dpaluy/reve_ai/actions/workflows/ci.yml/badge.svg)](https://github.com/dpaluy/reve_ai/actions/workflows/ci.yml)

## Installation

```
bundle add reve_ai
```

## Usage

Configure once:

```ruby
ReveAI.configure do |config|
  config.api_key = ENV.fetch("REVE_AI_API_KEY")
end
```

### Create Image

Generate an image from a text prompt:

```ruby
client = ReveAI::Client.new

response = client.images.create(prompt: "A beautiful sunset over mountains")

response.image          # => "base64encodeddata..."
response.version        # => "reve-create@20250915"
response.request_id     # => "rsid-..."
response.credits_used   # => 18
response.credits_remaining # => 982
```

With aspect ratio:

```ruby
response = client.images.create(
  prompt: "A beautiful sunset over mountains",
  aspect_ratio: "16:9"  # Options: 16:9, 9:16, 3:2, 2:3, 4:3, 3:4, 1:1 (default: 3:2)
)
```

With specific model version:

```ruby
response = client.images.create(
  prompt: "A beautiful sunset over mountains",
  version: "reve-create@20250915"  # Or "latest" (default)
)
```

### Edit Image

Modify an existing image using text instructions:

```ruby
require "base64"

client = ReveAI::Client.new

# Load and encode the image
image_data = Base64.strict_encode64(File.read("my-image.png"))

response = client.images.edit(
  edit_instruction: "Add dramatic clouds to the sky",
  reference_image: image_data
)

response.image   # => "base64editeddata..."
response.version # => "reve-edit@20250915"
```

Available versions for edit: `latest`, `latest-fast`, `reve-edit@20250915`, `reve-edit-fast@20251030`

### Remix Images

Combine text prompts with reference images to create new variations:

```ruby
require "base64"

client = ReveAI::Client.new

# Load and encode reference images
image1 = Base64.strict_encode64(File.read("person.png"))
image2 = Base64.strict_encode64(File.read("background.png"))

# Use <img>N</img> tags to reference specific images by index
response = client.images.remix(
  prompt: "The person from <img>0</img> standing in the scene from <img>1</img>",
  reference_images: [image1, image2],
  aspect_ratio: "16:9"  # Optional
)

response.image   # => "base64remixeddata..."
response.version # => "reve-remix@20250915"
```

Available versions for remix: `latest`, `latest-fast`, `reve-remix@20250915`, `reve-remix-fast@20251030`

### Rails

Create `config/initializers/reve_ai.rb`:

```ruby
ReveAI.configure do |c|
  c.api_key = Rails.application.credentials.dig(:reve, :api_key)
  # c.base_url = "https://api.reve.com"
  # c.timeout = 120
  # c.open_timeout = 30
  # c.max_retries = 2
end
```

### Error Handling

The gem provides detailed error classes for different scenarios:

```ruby
begin
  client.images.create(prompt: "A sunset")
rescue ReveAI::ValidationError => e
  # Input validation failed (prompt too long, invalid aspect ratio, etc.)
  puts "Validation error: #{e.message}"
rescue ReveAI::UnauthorizedError => e
  # Invalid API key (401)
  puts "Auth error: #{e.message}"
rescue ReveAI::InsufficientCreditsError => e
  # Budget has run out (402)
  puts "Out of credits: #{e.message}"
rescue ReveAI::UnprocessableEntityError => e
  # Inputs could not be understood (422)
  puts "Unprocessable: #{e.message}"
rescue ReveAI::RateLimitError => e
  # Rate limited (429) - check retry_after
  puts "Rate limited. Retry after: #{e.retry_after} seconds"
rescue ReveAI::BadRequestError => e
  # Invalid request parameters (400)
  puts "Bad request: #{e.message}"
rescue ReveAI::ServerError => e
  # Server-side error (5xx)
  puts "Server error: #{e.message}"
rescue ReveAI::TimeoutError => e
  # Request timed out
  puts "Timeout: #{e.message}"
rescue ReveAI::ConnectionError => e
  # Connection failed
  puts "Connection error: #{e.message}"
end
```

### Content Moderation

The API may flag content violations:

```ruby
response = client.images.create(prompt: "...")

if response.content_violation?
  puts "Content was flagged by moderation"
end
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `api_key` | `ENV["REVE_AI_API_KEY"]` | Your Reve API key |
| `base_url` | `https://api.reve.com` | API base URL |
| `timeout` | `120` | Request timeout in seconds |
| `open_timeout` | `30` | Connection timeout in seconds |
| `max_retries` | `2` | Number of retries for failed requests |
| `logger` | `nil` | Logger instance for debugging |
| `debug` | `false` | Enable debug logging |

### Validation Constraints

| Constraint | Value |
|------------|-------|
| Max prompt length | 2560 characters |
| Max reference images (remix) | 6 |
| Valid aspect ratios | 16:9, 9:16, 3:2, 2:3, 4:3, 3:4, 1:1 |

## Development

```
bundle install
bundle exec rake test
bundle exec rubocop
```

## Release  

```sh 
bundle exec rake release
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dpaluy/reve_ai.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

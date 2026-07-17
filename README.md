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

Save the image to a file:

```ruby
require "base64"

image_data = Base64.decode64(response.image)

File.open("output.png", "wb") do |f|
  f.write(image_data)
end
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

Available versions for edit: `latest`, `latest-fast`, `reve-edit@20250915`, `reve-edit-fast@20251030`, `reve-edit-passthrough@20260625`

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

### Postprocessing and Effects

The v1 `create`/`edit`/`remix` methods and `client.v2.images.create` accept these optional keyword arguments (`client.v2.layouts.render` also supports `postprocessing:` and `accept:`, and every endpoint supports `breadcrumb:`):

| Option | Values | Description |
|--------|--------|-------------|
| `postprocessing:` | Array of operation Hashes | Operations applied to the generated image (see below) |
| `test_time_scaling:` | `1`-`15` | Spend more effort (and credits) on the request; clamped server-side. Not recommended for v2 models |
| `accept:` | `"image/png"`, `"image/jpeg"`, `"image/webp"` | Return raw image bytes instead of JSON; metadata moves to `X-Reve-*` headers |
| `breadcrumb:` | String | Request-tracking tag, searchable on the Reve Usage page; ignored by the API |

Supported postprocessing operations:

| Operation | Parameters | Notes |
|-----------|------------|-------|
| `upscale` | `upscale_factor` (integer, 1-4) | Adds credits cost; a 4x upscale is large |
| `remove_background` | none | Adds credits cost; works best with a clear subject |
| `fit_image` | `max_dim`, `max_width`, and/or `max_height` (max 4096) | Free; scales down preserving aspect ratio |
| `effect` | `effect_name`, optional `effect_parameters` | Applies an effect saved in your project |

```ruby
response = client.images.create(
  prompt: "A beautiful sunset over mountains",
  postprocessing: [
    { process: "upscale", upscale_factor: 2 },
    { process: "fit_image", max_dim: 2048 }
  ],
  test_time_scaling: 3,
  breadcrumb: "homepage-hero"
)
```

Effect parameter overrides use a nested `{ filterId => { uniformId => value } }` format; omitted parameters fall back to the effect's saved defaults:

```ruby
response = client.images.create(
  prompt: "A high-quality photo of a wine bottle",
  postprocessing: [
    {
      process: "effect",
      effect_name: "adjustments",
      effect_parameters: {
        "adjustments" => {
          "u_exposure" => 42,
          "u_contrast" => -38,
          "u_vibrance" => 64
        }
      }
    }
  ]
)
```

List the effects available to your project — the returned `name` values are valid `effect_name` arguments:

```ruby
response = client.effects.list

response.body[:effects].each do |effect|
  puts "#{effect[:name]} (#{effect[:source]})" # source: "saved" (project) or "builtin" (preset)
end

# Optional source filter: "all" (default), "project" (saved only), "preset" (builtin only)
presets = client.effects.list(source: "preset")
```

### API v2

The v2 API collapses the three v1 workflows into a single endpoint, `client.v2.images.create`, which takes ordered reference images and returns a structured `layout` alongside the image. The v1 endpoints above remain live and unchanged.

- Prompts up to 4000 characters, and up to 8 reference images
- The full 18-value aspect-ratio set, including `auto` (the default) — see [Validation Constraints](#validation-constraints)
- References are objects with exactly one of `data:` (base64-encoded image) or `ref:` (`"id:<uuid>"` for a stored image or generation, `"reference:@<name>"` for a named project reference)
- Address a reference from the prompt as `<frame>N</frame>` (0-based: the first reference is `<frame>0</frame>`)
- v2 images are significantly larger than v1 — cap the output with a free `fit_image` step: `postprocessing: [{ process: "fit_image", max_dim: 2048 }]`

Generate an image from text:

```ruby
response = client.v2.images.create(prompt: "A beautiful sunset over mountains")

response.image   # => "base64encodeddata..."
response.version # => "latest" (v2 responses currently always report "latest")
```

Edit an image (pass it as the first reference and address it as `<frame>0</frame>`):

```ruby
require "base64"

image_data = Base64.strict_encode64(File.read("my-image.png"))

response = client.v2.images.create(
  prompt: "Add dramatic clouds to the sky of <frame>0</frame>",
  references: [{ data: image_data }]
)
```

Combine multiple references:

```ruby
person     = Base64.strict_encode64(File.read("person.png"))
background = Base64.strict_encode64(File.read("background.png"))

response = client.v2.images.create(
  prompt: "The person from <frame>0</frame> standing in the scene from <frame>1</frame>",
  references: [{ data: person }, { data: background }],
  aspect_ratio: "21:9"
)
```

Every v2 JSON response includes the layout the model generated for the image:

```ruby
response = client.v2.images.create(prompt: "A serene mountain landscape at sunset")

response.layout # => { prompt: "...", regions: [...], width: 4672, height: 3520 }

response.layout[:regions].each do |region|
  puts "#{region[:label]}: #{region[:prompt]}"
end
```

Request a binary image instead of JSON with `accept:` — `response.image` then holds the raw bytes, and the metadata arrives via `X-Reve-*` headers:

```ruby
response = client.v2.images.create(
  prompt: "A beautiful sunset over mountains",
  accept: "image/webp"
)

File.binwrite("mountains.webp", response.image) # no Base64 decoding needed

response.credits_used # => 150
```

Pass `version:` to pin a model alias — v2 aliases observed: `latest` (default), `reve-v2-create@260601`.

#### Migrating from v1 to v2

All three v1 workflows map to `client.v2.images.create`:

Create — keep `prompt` and `aspect_ratio`:

```ruby
# v1
client.images.create(prompt: "A serene mountain landscape at sunset",
                     aspect_ratio: "16:9", version: "latest")

# v2
client.v2.images.create(prompt: "A serene mountain landscape at sunset",
                        aspect_ratio: "16:9")
```

Edit — the edited image becomes `references[0]`, addressed as `<frame>0</frame>`:

```ruby
# v1
client.images.edit(edit_instruction: "Remove the people in the background.",
                   reference_image: image_b64)

# v2
client.v2.images.create(prompt: "Remove the people in the background of <frame>0</frame>.",
                        references: [{ data: image_b64 }])
```

Remix — `<img>N</img>` tags become `<frame>N</frame>` (both 0-based) and bare base64 strings become `{ data: }` objects:

```ruby
# v1
client.images.remix(prompt: "The woman from <img>0</img> driving the car from <img>1</img>.",
                    reference_images: [woman_b64, car_b64], aspect_ratio: "1:1")

# v2
client.v2.images.create(prompt: "The woman from <frame>0</frame> driving the car from <frame>1</frame>.",
                        references: [{ data: woman_b64 }, { data: car_b64 }], aspect_ratio: "1:1")
```

#### Experimental Layout Endpoints

The layout endpoints are **experimental**: they require care and experimentation to achieve good results, are best suited for agents and custom tooling, and may change. For simple generation and prompt-based editing, use `client.v2.images.create`. They return JSON only (`render` also supports `accept:`) and commonly take 10-40 seconds (`render`: 40-80 seconds) — keep timeouts at 120 seconds or more.

A layout is a Hash with an optional overall `prompt`, optional `width`/`height`, and a `regions` array; each region carries a `label`, a regional `prompt`, and a normalized `bbox` (`x0`, `y0`, `x1`, `y1` in 0.0-1.0, top-left origin).

Extract a layout from an image:

```ruby
image = { data: Base64.strict_encode64(File.read("photo.jpg")) }

response = client.v2.layouts.extract(image: image)
response.layout # => { prompt: "...", regions: [...], width: 4672, height: 3520 }
```

Create a layout from a prompt, without rendering an image:

```ruby
response = client.v2.layouts.create(prompt: "a person at a cafe", aspect_ratio: "3:2")
layout = response.layout
```

Render an image from a layout:

```ruby
response = client.v2.layouts.render(layout: layout)
response.image # => "base64encodeddata..."
```

Unlike v2 create, the layout endpoints take compound references — each entry may contain any subset of `image:`, `layout:`, and `prompt:`:

```ruby
response = client.v2.layouts.create(
  prompt: "Put the bottle on a wooden table",
  references: [
    { image: { data: bottle_b64 }, prompt: "the product to feature" },
    { layout: saved_layout }
  ]
)
```

`create` also accepts `commands:` — ordered imperative edits (`add`, `place`, `shift`, `remove`, `keep`, `change`) with normalized positions; see the [API docs](https://api.reve.com/console/docs) for the command shapes.

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

Every API error also exposes the details returned by the API:

```ruby
rescue ReveAI::APIError => e
  e.error_code # => "PROMPT_TOO_LONG"
  e.params     # => Hash of error-specific parameters, or nil
  e.status     # => 400
  e.request_id # => "rsid-..."
end
```

For binary image requests (`accept: "image/*"`), error responses carry a small grey image and the error code arrives in the `X-Reve-Error-Code` header — `#error_code` reads it from either the response body or the header.

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
| `timeout` | `120` | Request timeout in seconds (the API requires at least 120) |
| `open_timeout` | `30` | Connection timeout in seconds |
| `max_retries` | `2` | Number of retries for failed requests |
| `logger` | `nil` | Logger instance for debugging |
| `debug` | `false` | Enable debug logging |

The API requires client timeouts of at least 120 seconds: image generation and rendering commonly take 40-80 seconds, and the layout endpoints 10-40 seconds. The gem's default of 120 seconds complies. Treat shorter client-side timeouts as cancellations — the server may still finish the request after the client disconnects.

### Validation Constraints

v1 endpoints (`create`, `edit`, `remix`):

| Constraint | Value |
|------------|-------|
| Max prompt length | 2560 characters |
| Max reference images (remix) | 6 |
| Valid aspect ratios | 16:9, 9:16, 3:2, 2:3, 4:3, 3:4, 1:1 |

v2 endpoints (`client.v2`):

| Constraint | Value |
|------------|-------|
| Max prompt length | 4000 characters |
| Max reference images | 8 |
| Valid aspect ratios | 4:1, 3:1, 21:9, 2:1, 17:9, 16:9, 3:2, 4:3, 5:4, 1:1, 4:5, 3:4, 2:3, 9:16, 1:2, 1:3, 1:4, auto (default: auto) |

Input image limits (any endpoint that accepts images):

- Formats: WEBP, JPEG, PNG, GIF, TIFF, AVIF — base64-encoded in JSON
- Per image: at most 40 MB and 33,554,432 pixels, with neither dimension exceeding 8192 pixels
- Per call: at most 100 MB and 50,331,648 pixels across all images

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

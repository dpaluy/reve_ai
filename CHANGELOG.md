# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-08-05

### Deprecated

- Documented the Reve public API shutdown and the gem's deprecated, unmaintained status
- Added a RubyGems post-install warning with the API sunset date and repository README link

## [0.2.0] - 2026-07-17

### Added

- API v2 image creation via `client.v2.images.create` (`POST /v2/image/create`): ordered `references`
  (`{ data: }` / `{ ref: }` objects addressed from the prompt as `<frame>N</frame>`), the full
  18-value aspect-ratio set including `auto`, prompts up to 4000 characters, and up to 8 references
- Experimental layout endpoints under `client.v2.layouts`: `extract` (`POST /v2/image/extract_layout`),
  `create` (`POST /v2/image/create_layout`), and `render` (`POST /v2/image/render_layout`)
- Effects listing via `client.effects.list` (`GET /v1/image/effect`) with an optional `source` filter
- `postprocessing:`, `test_time_scaling:`, `accept:`, and `breadcrumb:` options on the v1
  `create`/`edit`/`remix` and v2 endpoints
- Binary image responses: `accept: "image/png"`, `"image/jpeg"`, or `"image/webp"` returns raw image
  bytes with metadata in `X-Reve-*` headers
- `ImageResponse#layout` and `ReveAI::LayoutResponse` for the structured layouts returned by v2 endpoints
- `APIError#params` for the error-specific `params` object returned by the API, and `APIError#error_code`
  now falls back to the `X-Reve-Error-Code` header (binary error responses)
- GET support in the HTTP layer; retries now cover GET requests as well as POST

### Fixed

- Remix `<img>N</img>` YARD documentation corrected to 0-based indexing, matching the API

## [0.1.0] - 2026-01-04

### Added

- Initial release
- `ReveAI::Client` for API authentication and configuration
- Image generation via `client.images.generate`
- Image editing via `client.images.edit`
- Image remix via `client.images.remix`
- Automatic retry with exponential backoff via Faraday
- Configurable timeouts and base URL

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-04

### Added

- Initial release
- `ReveAI::Client` for API authentication and configuration
- Image generation via `client.images.generate`
- Image editing via `client.images.edit`
- Image remix via `client.images.remix`
- Automatic retry with exponential backoff via Faraday
- Configurable timeouts and base URL

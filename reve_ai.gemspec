# frozen_string_literal: true

require_relative "lib/reve_ai/version"

Gem::Specification.new do |spec|
  spec.name = "reve_ai"
  spec.version = ReveAI::VERSION
  spec.authors = ["dpaluy"]
  spec.email = ["dpaluy@users.noreply.github.com"]

  spec.summary = "Deprecated Ruby client for Reve's sunset image generation API."
  spec.description = "ReveAI was a lightweight Faraday-based wrapper for the Reve image generation API " \
                     "(create, edit, remix images). The upstream public API sunsets on August 14, 2026; " \
                     "this gem is deprecated and will be unmaintained after the shutdown."
  spec.homepage = "https://github.com/dpaluy/reve_ai"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/reve_ai"
  spec.metadata["source_code_uri"] = "https://github.com/dpaluy/reve_ai"
  spec.metadata["changelog_uri"] = "https://github.com/dpaluy/reve_ai/blob/master/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/dpaluy/reve_ai/issues"
  spec.metadata["deprecated"] = "true"

  spec.post_install_message = <<~MESSAGE
    WARNING: The upstream Reve public API sunsets Friday, August 14, 2026.
    This gem is deprecated and will be unmaintained after the shutdown.
    Existing approved API users retain access through the sunset window; all other users can no longer access it, and new API onboarding is closed.
    Unused paid credits begin full-refund processing Monday, August 17, 2026.
    See the repository README for details: https://github.com/dpaluy/reve_ai#api-sunset-notice
  MESSAGE

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ .git .github/ .rubocop.yml .yardopts Gemfile CLAUDE.md AGENTS.md .agents.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Include documentation files
  spec.extra_rdoc_files = Dir["README.md", "CHANGELOG.md", "LICENSE.txt"]

  # Runtime dependencies
  spec.add_dependency "base64", "~> 0.3"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
end

# frozen_string_literal: true

require_relative "../test_helper"

class GemspecTest < Minitest::Test
  def test_version_and_deprecation_metadata_are_discoverable
    assert_equal Gem::Version.new("0.2.1"), gemspec.version
    assert_includes gemspec.summary.downcase, "deprecated"
    assert_includes gemspec.description.downcase, "unmaintained"
    assert_equal "true", gemspec.metadata["deprecated"]
  end

  def test_post_install_message_warns_about_api_sunset
    message = gemspec.post_install_message

    assert_includes message, "August 14, 2026"
    assert_includes message, "deprecated"
    assert_includes message, "https://github.com/dpaluy/reve_ai#api-sunset-notice"
  end

  def test_base64_is_a_runtime_dependency
    dependency = gemspec.runtime_dependencies.find { |candidate| candidate.name == "base64" }

    refute_nil dependency
    assert_equal Gem::Requirement.new("~> 0.3"), dependency.requirement
  end

  private

  def gemspec
    @gemspec ||= Gem::Specification.load(File.expand_path("../../reve_ai.gemspec", __dir__))
  end
end

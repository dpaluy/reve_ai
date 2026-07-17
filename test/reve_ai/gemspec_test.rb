# frozen_string_literal: true

require_relative "../test_helper"

class GemspecTest < Minitest::Test
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

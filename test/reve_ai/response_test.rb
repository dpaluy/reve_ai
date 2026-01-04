# frozen_string_literal: true

require "test_helper"

class ReveAI::ResponseTest < Minitest::Test
  def test_stores_status_headers_and_body
    response = ReveAI::Response.new(
      status: 200,
      headers: { "content-type" => "application/json" },
      body: { image: "base64data" }
    )

    assert_equal 200, response.status
    assert_equal({ "content-type" => "application/json" }, response.headers)
    assert_equal({ image: "base64data" }, response.body)
  end

  def test_success_returns_true_for_two_hundred_range
    response = ReveAI::Response.new(status: 200, headers: {}, body: {})
    assert response.success?

    response = ReveAI::Response.new(status: 201, headers: {}, body: {})
    assert response.success?
  end

  def test_success_returns_false_for_non_two_hundred_range
    response = ReveAI::Response.new(status: 400, headers: {}, body: {})
    refute response.success?

    response = ReveAI::Response.new(status: 500, headers: {}, body: {})
    refute response.success?
  end

  def test_request_id_from_body
    response = ReveAI::Response.new(
      status: 200,
      headers: {},
      body: { request_id: "rsid-123" }
    )

    assert_equal "rsid-123", response.request_id
  end

  def test_request_id_from_headers
    response = ReveAI::Response.new(
      status: 200,
      headers: { "x-reve-request-id" => "rsid-456" },
      body: {}
    )

    assert_equal "rsid-456", response.request_id
  end
end

class ReveAI::ImageResponseTest < Minitest::Test
  def test_image_returns_base64_data
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: {},
      body: { image: "base64encodeddata" }
    )

    assert_equal "base64encodeddata", response.image
  end

  def test_base64_is_alias_for_image
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: {},
      body: { image: "base64encodeddata" }
    )

    assert_equal response.image, response.base64
  end

  def test_version_from_body
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: {},
      body: { version: "reve-create@20250915" }
    )

    assert_equal "reve-create@20250915", response.version
  end

  def test_version_from_headers
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: { "x-reve-version" => "reve-edit@20250915" },
      body: {}
    )

    assert_equal "reve-edit@20250915", response.version
  end

  def test_content_violation_from_body
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: {},
      body: { content_violation: true }
    )

    assert response.content_violation?
  end

  def test_content_violation_from_headers
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: { "x-reve-content-violation" => "true" },
      body: {}
    )

    assert response.content_violation?
  end

  def test_content_violation_false_by_default
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: {},
      body: {}
    )

    refute response.content_violation?
  end

  def test_credits_used_from_body
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: {},
      body: { credits_used: 18 }
    )

    assert_equal 18, response.credits_used
  end

  def test_credits_used_from_headers
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: { "x-reve-credits-used" => "30" },
      body: {}
    )

    assert_equal 30, response.credits_used
  end

  def test_credits_remaining_from_body
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: {},
      body: { credits_remaining: 982 }
    )

    assert_equal 982, response.credits_remaining
  end

  def test_credits_remaining_from_headers
    response = ReveAI::ImageResponse.new(
      status: 200,
      headers: { "x-reve-credits-remaining" => "970" },
      body: {}
    )

    assert_equal 970, response.credits_remaining
  end
end

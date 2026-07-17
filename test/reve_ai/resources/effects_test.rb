# frozen_string_literal: true

require "test_helper"

class ReveAI::Resources::EffectsTest < Minitest::Test
  def setup
    super
    @client = ReveAI::Client.new(api_key: "test_key")
    @effects = ReveAI::Resources::Effects.new(@client)
  end

  def test_inherits_from_base
    assert_kind_of ReveAI::Resources::Base, @effects
  end

  def test_list_returns_all_effects_by_default
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .to_return(
        status: 200,
        body: fixture("effects_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @effects.list

    assert_instance_of ReveAI::Response, response
    effects = response.body[:effects]
    assert_equal 2, effects.length
    assert_equal "cmyk_halftone", effects[0][:name]
    assert_equal "builtin", effects[0][:source]
    assert_equal "CMYK halftone print effect", effects[0][:description]
    assert_equal "textures", effects[0][:category]
    assert_equal({ name: "my-saved-effect", source: "saved" }, effects[1])
  end

  def test_list_with_source_filter
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .with(query: { source: "project" })
      .to_return(
        status: 200,
        body: fixture("effects_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @effects.list(source: "project")

    assert response.success?
  end

  def test_list_with_breadcrumb_sends_query_param
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .with(query: { breadcrumb: "effects-audit" })
      .to_return(
        status: 200,
        body: fixture("effects_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @effects.list(breadcrumb: "effects-audit")

    assert response.success?
  end

  def test_list_validates_source
    error = assert_raises(ReveAI::ValidationError) do
      @effects.list(source: "invalid")
    end
    assert_match(/Invalid source 'invalid'/, error.message)
  end
end

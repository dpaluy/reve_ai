# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "reve_ai"
require "minitest/autorun"
require "webmock/minitest"

class Minitest::Test
  def setup
    WebMock.disable_net_connect!
    ReveAI.reset_configuration!
  end

  def teardown
    WebMock.reset!
  end

  def fixture_path(name)
    File.join(__dir__, "fixtures", name)
  end

  def fixture(name)
    File.read(fixture_path(name))
  end

  def fixture_json(name)
    JSON.parse(fixture(name), symbolize_names: true)
  end
end

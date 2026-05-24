require "test_helper"

class OmniAuthTest < ActiveSupport::TestCase
  test "uses the configured app base url as full_host" do
    assert_equal "http://example.com", OmniAuth.config.full_host
  end
end

require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "returns success for the healthcheck endpoint" do
    get rails_health_check_url

    assert_response :success
  end
end

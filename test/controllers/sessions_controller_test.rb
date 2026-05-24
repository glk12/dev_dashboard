require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "renders login on canonical host" do
    get login_url

    assert_response :success
  end

  test "redirects non-canonical hosts to the configured base url" do
    host! "127.0.0.1"

    get "/login"

    assert_redirected_to "http://example.com/login"
  end
end

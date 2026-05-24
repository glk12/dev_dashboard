require "test_helper"

class MyPullRequestsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users from index" do
    get my_pull_requests_url

    assert_redirected_to login_path
  end
end

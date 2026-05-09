require "test_helper"

class MyPullRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get my_pull_requests_index_url
    assert_response :success
  end
end

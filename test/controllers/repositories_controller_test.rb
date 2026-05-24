require "test_helper"

class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users from index" do
    get repositories_url

    assert_redirected_to login_path
  end

  test "toggle redirects unauthenticated users" do
    patch toggle_repositories_url, params: {
      repository: {
        name: "repo",
        owner: "owner",
        repo_name: "repo",
        default_branch: "main",
        active: true
      }
    }

    assert_redirected_to login_path
  end
end

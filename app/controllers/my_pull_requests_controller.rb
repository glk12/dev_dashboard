class MyPullRequestsController < ApplicationController
  before_action :require_authentication
  before_action :require_github_credential

  def index
    repositories = Repository.active

    pull_requests = Github::PullRequestsFetcher.new(
      repositories: repositories,
      user: current_user
    ).call

    @kanban = Github::PullRequestKanban.new(pull_requests)
    # Hash with each column and its pull requests
    @kanban_columns = @kanban.columns
  end
end

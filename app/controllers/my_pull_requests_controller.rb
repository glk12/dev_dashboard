class MyPullRequestsController < ApplicationController
  def index
    repositories = Repository.active

    pull_requests = Github::PullRequestsFetcher.new(repositories: repositories).call

    @kanban = Github::PullRequestKanban.new(pull_requests)
    # Hash with each column and its pull requests
    @kanban_columns = @kanban.columns
  end
end

module Github
  class PullRequestsFetcher
    def initialize(repositories:, username: nil, access_token: nil)
      @repositories = repositories
      @username = username || default_username
      @client = Github::Client.new(access_token: access_token)
    end
      
    def call
      @repositories.flat_map do |repository|
        pull_requests_for(repository)
      end
    end

    private

    # returns the pull_request data
    def pull_requests_for(repository)
      @client.open_pull_requests(repository.full_name).filter_map do |pull_request|
        next unless pull_request.user.login == @username

        build_pull_request_data(repository, pull_request)
      end
    rescue Octokit::Error => e
      Rails.logger.error("Github API error for #{repository.full_name}: #{e.class} - #{e.message}")

      []
    end

    def build_pull_request_data(repository, pull_request)
      {
        repository_name: repository.name,
        repository_full_name: repository.full_name,
        number: pull_request.number,
        title: pull_request.title,
        author: pull_request.user.login,
        head_ref: pull_request.head.ref,
        base_ref: pull_request.base.ref,
        draft: pull_request.draft,
        state: pull_request.state,
        url: pull_request.html_url,
        created_at: pull_request.created_at,
        updated_at: pull_request.updated_at 
      }
    end

    def default_username
      Rails.application.credentials.dig(:github, :username)
    end
  end
end
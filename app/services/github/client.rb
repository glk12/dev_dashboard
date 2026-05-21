require "octokit"

module Github
  class Client
    def initialize(access_token: nil)
      raise ArgumentError, "Github access token is required" if access_token.blank?

      @client = Octokit::Client.new(access_token: access_token)
      @client.auto_paginate = true
    end

    def open_pull_requests(repository_full_name)
      @client.pull_requests(repository_full_name, state: "open")
    end

    def pull_request_reviews(repository_full_name, pull_number)
      @client.pull_request_reviews(repository_full_name, pull_number)
    end
  end
end

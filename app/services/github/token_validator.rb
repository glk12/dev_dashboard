module Github
  class TokenValidator
    Result = Struct.new(:success?, :login, :error_message, keyword_init: true)

    def initialize(token:, expected_login:)
      @token = token
      @expected_login = expected_login
    end

    def call
      client = Github::Client.new(access_token: token)
      github_user = client.authenticated_user

      if github_user.login.to_s.casecmp(expected_login.to_s) != 0
        return Result.new(
          success?: false,
          login: github_user.login,
          error_message: "This token belongs to @#{github_user.login}, but you are signed in as @#{expected_login}."
        )
      end

      Result.new(success?: true, login: github_user.login, error_message: nil)
    rescue Octokit::Unauthorized
      Result.new(success?: false, login: nil, error_message: "Invalid GitHub token.")
    rescue Octokit::Forbidden => e
      Result.new(success?: false, login: nil, error_message: "GitHub rejected this token: #{e.message}")
    rescue Octokit::Error => e
      Result.new(success?: false, login: nil, error_message: "Could not validate token with GitHub: #{e.message}")
    rescue ArgumentError => e
      Result.new(success?: false, login: nil, error_message: e.message)
    end

    private

    attr_reader :token, :expected_login
  end
end

module Github
  class OauthUserUpserter   
    def initialize(auth)
      @auth = auth
    end

    def call
      user = User.find_or_initialize_by(github_uid: auth.uid)

      user.assign_attributes(
        github_login: auth.info.nickname,
        github_name: auth.info.name,
        github_email: auth.info.email,
        github_avatar_url: auth.info.image,
        github_profile_url: github_profile_url,
        oauth_provider: auth.provider,
        last_signed_in_at: Time.current
      )

      user.save!
      user
    end

    private

    attr_reader :auth

    def github_profile_url
      auth.info.urls&.Github
    end
  end
end
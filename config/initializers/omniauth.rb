app_base_url = Rails.application.config.x.app_base_url

OmniAuth.config.full_host = app_base_url if app_base_url.present?

github_oauth_client_id = ENV["GITHUB_OAUTH_CLIENT_ID"]
github_oauth_client_secret = ENV["GITHUB_OAUTH_CLIENT_SECRET"]

if (github_oauth_client_id.blank? || github_oauth_client_secret.blank?) &&
   (ENV["RAILS_MASTER_KEY"].present? || Rails.root.join("config/master.key").exist?)
  github_oauth_client_id ||= Rails.application.credentials.dig(:github, :oauth_client_id)
  github_oauth_client_secret ||= Rails.application.credentials.dig(:github, :oauth_client_secret)
end

Rails.application.config.middleware.use OmniAuth::Builder do
  if github_oauth_client_id.present? && github_oauth_client_secret.present?
    provider :github,
             github_oauth_client_id,
             github_oauth_client_secret,
             scope: "read:user,user:email"
  else
    Rails.logger.warn("GitHub OAuth credentials are not configured; GitHub login is disabled.")
  end
end

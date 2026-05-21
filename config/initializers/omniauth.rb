Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
           Rails.application.credentials.dig(:github, :oauth_client_id),
           Rails.application.credentials.dig(:github, :oauth_client_secret),
           scope: "read:user,user:email"
end
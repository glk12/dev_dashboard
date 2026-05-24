app_base_url = Rails.application.config.x.app_base_url

if app_base_url.present?
  uri = URI.parse(app_base_url)
  default_url_options = {
    protocol: uri.scheme,
    host: uri.host,
    port: uri.port
  }

  Rails.application.routes.default_url_options = default_url_options
  Rails.application.config.action_mailer.default_url_options = default_url_options
end

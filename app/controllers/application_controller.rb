class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  helper_method :current_user, :authenticated?
  before_action :ensure_canonical_host

  stale_when_importmap_changes

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def authenticated?
    current_user.present?
  end

  def require_authentication
    return if authenticated?

    redirect_to login_path
  end

  def require_github_credential
    return if current_user.github_credential.present?

    redirect_to edit_github_token_path, alert: "Connect your Github token to continue."
  end

  def ensure_canonical_host
    app_base_url = Rails.application.config.x.app_base_url
    return if app_base_url.blank?
    return unless request.get? || request.head?
    return if request.base_url == app_base_url

    redirect_to "#{app_base_url}#{request.fullpath}", status: :temporary_redirect, allow_other_host: true
  end
end

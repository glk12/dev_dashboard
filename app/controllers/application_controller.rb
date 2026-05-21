class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  helper_method :current_user, :authenticated?
  

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
end
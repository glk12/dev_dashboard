class SessionsController < ApplicationController
  def new
    return unless authenticated?

    if current_user.github_credential.present?
      redirect_to root_path
    else
      redirect_to edit_github_token_path
    end
  end

  def create
    user = Github::OauthUserUpserter.new(request.env["omniauth.auth"]).call

    session[:user_id] = user.id

    if user.github_credential.present?
      redirect_to root_path
    else
      redirect_to edit_github_token_path
    end
  end

  def destroy
    reset_session

    redirect_to login_path
  end

  def failure
    redirect_to login_path, alert: "Could not authenticate with GitHub."
  end
end

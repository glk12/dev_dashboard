class GithubCredentialsController < ApplicationController
  before_action :require_authentication

  def edit
    @github_credential = current_user.github_credential ||
                         current_user.build_github_credential
  end

  def update
    token = github_credential_params[:fine_grained_token]

    @github_credential = current_user.github_credential ||
                         current_user.build_github_credential

    @github_credential.assign_attributes(
      fine_grained_token: token,
      token_last_four: token.to_s.last(4),
      last_validated_at: Time.current,
      last_validation_error: nil,
      active: true
    )

    if @github_credential.save
      redirect_to root_path, notice: "GitHub token connected successfully."
    else
      flash.now[:alert] = @github_credential.errors.full_messages.to_sentence.presence || "Could not save GitHub token."
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    current_user.github_credential&.destroy

    redirect_to edit_github_token_path, notice: "GitHub token disconnected."
  end

  private

  def github_credential_params
    params.require(:user_github_credential).permit(:fine_grained_token)
  end
end

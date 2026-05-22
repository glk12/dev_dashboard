class RepositoriesController < ApplicationController
  before_action :require_authentication
  before_action :require_github_credential
  before_action :set_github_client, only: %i[ index toggle ]

  def index
    repositories_by_full_name = Repository.all.index_by(&:full_name)

    @available_repositories = @github_client.accessible_repositories.map do |github_repository|
      repository = repositories_by_full_name[github_repository.full_name]

      {
        name: github_repository.name,
        owner: github_repository.owner.login,
        repo_name: github_repository.name,
        full_name: github_repository.full_name,
        default_branch: github_repository.default_branch,
        private: github_repository.private,
        active: repository&.active? || false,
        persisted: repository.present?,
        repository: repository
      }
    end
  end

  def toggle
    repository = Repository.find_or_initialize_by(
      owner: repository_toggle_params[:owner],
      repo_name: repository_toggle_params[:repo_name]
    )

    repository.assign_attributes(
      name: repository_toggle_params[:name],
      default_branch: repository_toggle_params[:default_branch],
      active: ActiveModel::Type::Boolean.new.cast(repository_toggle_params[:active])
    )

    if repository.save
      notice = repository.active? ? "Repository activated successfully." : "Repository deactivated successfully."
      redirect_to repositories_path, notice: notice
    else
      redirect_to repositories_path, alert: repository.errors.full_messages.to_sentence
    end
  end

  private
    def repository_toggle_params
      params.expect(repository: [ :name, :owner, :repo_name, :default_branch, :active ])
    end

    def set_github_client
      @github_client = Github::Client.new(access_token: current_user.github_credential.fine_grained_token)
    end
end

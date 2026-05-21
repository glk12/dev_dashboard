class User < ApplicationRecord
  has_one :github_credential,
          class_name: "UserGithubCredential",
          dependent: :destroy
  validates :github_uid, presence: true, uniqueness: true
  validates :github_login, presence: true
end


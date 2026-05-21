class UserGithubCredential < ApplicationRecord
  belongs_to :user

  encrypts :fine_grained_token

  validates :fine_grained_token, presence: true
end

class Repository < ApplicationRecord
  validates :name, :owner, :repo_name, :default_branch, presence: true

  scope :active, -> { where(active: true) }

  def full_name
    "#{owner}/#{repo_name}"
  end
end

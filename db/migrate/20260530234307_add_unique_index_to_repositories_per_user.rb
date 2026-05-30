class AddUniqueIndexToRepositoriesPerUser < ActiveRecord::Migration[8.1]
  def change
    add_index :repositories, [:user_id, :owner, :repo_name], unique: true
  end
end

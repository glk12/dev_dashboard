class MakeUserIdRequiredOnRepositories < ActiveRecord::Migration[8.1]
  def change
    change_column_null :repositories, :user_id, false
  end
end

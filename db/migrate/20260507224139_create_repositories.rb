class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.string :name
      t.string :owner
      t.string :repo_name
      t.string :default_branch
      t.boolean :active

      t.timestamps
    end
  end
end

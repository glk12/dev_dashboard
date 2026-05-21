class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :github_uid, null: false
      t.string :github_login, null: false
      t.string :github_name
      t.string :github_email
      t.string :github_avatar_url
      t.string :github_profile_url
      t.string :oauth_provider, null: false, default: "github"
      t.datetime :last_signed_in_at

      t.timestamps
    end

    add_index :users, :github_uid, unique: true
    add_index :users, :github_login
  end
end

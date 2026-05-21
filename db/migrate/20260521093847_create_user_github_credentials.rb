class CreateUserGithubCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :user_github_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.text :fine_grained_token, null: false
      t.string :token_last_four
      t.jsonb :token_permissions_snapshot, null: false, default: {}
      t.jsonb :token_repository_access_snapshot, null: false, default: {}
      t.datetime :token_expires_at
      t.datetime :last_validated_at
      t.text :last_validation_error
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end

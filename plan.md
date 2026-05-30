# Associating Repositories With Users

This guide shows how to change the current data model so each authenticated user has their own repository list and activation state.

Today, `Repository` is global. After this change, each `Repository` record will belong to a `User`, which fixes the isolation problem between accounts.

## Goal

We want this:

- User A activates `org/repo-1`
- User B activates `org/repo-2`
- User A only affects User A's dashboard
- User B only affects User B's dashboard

Instead of this:

- one shared `repositories` table controls the dashboard behavior for every account

## Why This Matters

Your GitHub token already limits what each user can read from GitHub. That part is fine.

The problem is the app database state:

- the selected repositories are currently stored globally
- the dashboard currently reads all active repositories globally
- one signed-in user can change what another signed-in user tracks

So the fix is not about GitHub permission bypass. It is about per-user ownership inside your app.

## Overview Of The Change

You will:

1. Add a `user_id` foreign key to `repositories`
2. Backfill existing rows if needed
3. Make `Repository` belong to `User`
4. Make `User` have many `repositories`
5. Scope reads and writes to `current_user`
6. Update tests

## Step 1: Generate The Migration

Run:

```bash
bin/rails generate migration AddUserToRepositories user:references
```

What this does:

- creates a migration file
- adds a `user_id` column
- prepares the foreign key relationship from `repositories` to `users`

Rails will generate something close to:

```ruby
class AddUserToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_reference :repositories, :user, null: false, foreign_key: true
  end
end
```

Important:

- if you already have rows in `repositories`, `null: false` may fail immediately because old records do not have a `user_id` yet
- in that case, use a safer two-step migration shown below

## Step 2: Use A Safe Migration If Data Already Exists

If the table may already contain records, edit the generated migration to something like this:

```ruby
class AddUserToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_reference :repositories, :user, null: true, foreign_key: true
  end
end
```

Then run:

```bash
bin/rails db:migrate
```

Why:

- first add the column without breaking existing data
- backfill data
- only then make it required

## Step 3: Backfill Existing Records

If this app is only yours and there is already one real user in the database, you can attach all existing repositories to that user.

Open the Rails console:

```bash
bin/rails console
```

Then run:

```ruby
user = User.first
Repository.where(user_id: nil).update_all(user_id: user.id)
```

Explanation:

- `User.first` grabs the first existing account
- `update_all` assigns ownership of all old repository records
- this is acceptable for a small personal app

If you have multiple real users already, do not use this blindly. In that case, you need a deliberate mapping strategy.

## Step 4: Make `user_id` Required

Generate a second migration:

```bash
bin/rails generate migration MakeUserIdRequiredOnRepositories
```

Edit it to:

```ruby
class MakeUserIdRequiredOnRepositories < ActiveRecord::Migration[8.1]
  def change
    change_column_null :repositories, :user_id, false
  end
end
```

Then run:

```bash
bin/rails db:migrate
```

Why this second migration exists:

- it keeps the rollout safe
- you avoid breaking production before backfilling the old records

## Step 5: Update The Models

Edit `app/models/user.rb`.

Add:

```ruby
has_many :repositories, dependent: :destroy
```

Why:

- each user now owns many repository records
- `dependent: :destroy` keeps the database clean if a user is ever removed

Edit `app/models/repository.rb`.

Add:

```ruby
belongs_to :user
```

You will end up with something like:

```ruby
class Repository < ApplicationRecord
  belongs_to :user

  validates :name, :owner, :repo_name, :default_branch, presence: true

  scope :active, -> { where(active: true) }

  def full_name
    "#{owner}/#{repo_name}"
  end
end
```

## Step 6: Scope Repository Reads To The Current User

Update `app/controllers/repositories_controller.rb`.

Change this:

```ruby
repositories_by_full_name = Repository.all.index_by(&:full_name)
```

To this:

```ruby
repositories_by_full_name = current_user.repositories.index_by(&:full_name)
```

Why:

- the repository settings page should only reflect the current user's saved choices

## Step 7: Scope Repository Writes To The Current User

Still in `app/controllers/repositories_controller.rb`, change the `toggle` lookup.

Change this:

```ruby
repository = Repository.find_or_initialize_by(
  owner: repository_toggle_params[:owner],
  repo_name: repository_toggle_params[:repo_name]
)
```

To this:

```ruby
repository = current_user.repositories.find_or_initialize_by(
  owner: repository_toggle_params[:owner],
  repo_name: repository_toggle_params[:repo_name]
)
```

Why:

- activation state becomes private to the signed-in user
- one user can no longer overwrite another user's repository row

## Step 8: Scope The Dashboard Query

Update `app/controllers/my_pull_requests_controller.rb`.

Change this:

```ruby
repositories = Repository.active
```

To this:

```ruby
repositories = current_user.repositories.active
```

Why:

- the PR dashboard should only use repositories activated by the current user

## Step 9: Add Or Update Model Validations

In `app/models/repository.rb`, it is reasonable to validate uniqueness per user.

Add:

```ruby
validates :repo_name, uniqueness: { scope: [ :user_id, :owner ] }
```

Why:

- prevents duplicate rows like the same user saving `rails/rails` multiple times
- still allows different users to track the same GitHub repository independently

## Step 10: Add A Database Index For That Rule

Generate another migration:

```bash
bin/rails generate migration AddUniqueIndexToRepositoriesPerUser
```

Edit it to:

```ruby
class AddUniqueIndexToRepositoriesPerUser < ActiveRecord::Migration[8.1]
  def change
    add_index :repositories, [ :user_id, :owner, :repo_name ], unique: true
  end
end
```

Then run:

```bash
bin/rails db:migrate
```

Why both validation and index:

- model validation gives friendly application-level feedback
- database index is the real protection against race conditions and duplicate rows

## Step 11: Update Fixtures And Tests

You will probably need to update:

- `test/fixtures/repositories.yml`
- controller tests
- model tests

Most likely change:

- add `user: one` or `user_id: ...` to repository fixtures

Example fixture shape:

```yml
active_repo:
  user: one
  name: rails
  owner: rails
  repo_name: rails
  default_branch: main
  active: true
```

Why tests will fail otherwise:

- once `Repository` belongs to `User`, fixtures without `user_id` become invalid

## Step 12: Run The Test Suite

Run:

```bash
bin/rails test
```

If you want to focus first on the affected areas:

```bash
bin/rails test test/models test/controllers
```

## Recommended Final State

After the refactor, the important controller lines should look roughly like this:

```ruby
repositories_by_full_name = current_user.repositories.index_by(&:full_name)
```

```ruby
repository = current_user.repositories.find_or_initialize_by(
  owner: repository_toggle_params[:owner],
  repo_name: repository_toggle_params[:repo_name]
)
```

```ruby
repositories = current_user.repositories.active
```

## Full Suggested Command Sequence

If you want the short execution order:

```bash
bin/rails generate migration AddUserToRepositories user:references
bin/rails db:migrate
bin/rails console
bin/rails generate migration MakeUserIdRequiredOnRepositories
bin/rails generate migration AddUniqueIndexToRepositoriesPerUser
bin/rails db:migrate
bin/rails test
```

Console command during the sequence:

```ruby
user = User.first
Repository.where(user_id: nil).update_all(user_id: user.id)
```

## Practical Advice For Your Case

Because this is a portfolio app and likely has little or no production data yet, this migration should be pretty manageable.

If the app is still only used by you, the backfill is simple. If you plan to let more people sign in later, this refactor is absolutely worth doing now while the data model is still small.

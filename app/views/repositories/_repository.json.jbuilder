json.extract! repository, :id, :name, :owner, :repo_name, :default_branch, :active, :created_at, :updated_at
json.url repository_url(repository, format: :json)

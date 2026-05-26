# Dev Dashboard

Personal dashboard for tracking your own GitHub pull requests across multiple repositories.

This project was built as a focused productivity tool: sign in with GitHub, connect a fine-grained personal access token, choose which repositories should be monitored, and view your open PRs in a clean kanban-style board grouped by review status.

## Preview

The app is centered around a simple workflow:

- Authenticate with GitHub OAuth
- Connect a fine-grained GitHub token from the same account
- Select the repositories you want to monitor
- See your open pull requests organized as:
  - `Draft`
  - `Waiting Review`
  - `Changes Requested`
  - `Approved`

## Features

- GitHub OAuth login
- Fine-grained token validation against the authenticated GitHub account
- Repository discovery based on the connected token permissions
- Per-repository activation toggle for dashboard tracking
- PR board filtered to the current user's open pull requests
- Review-aware status grouping using GitHub review state
- Encrypted token storage with Active Record Encryption
- Docker and Kamal deployment setup for a single VPS

## Tech Stack

- Ruby `3.2.2`
- Rails `8.1`
- PostgreSQL
- Hotwire
  - Turbo
  - Stimulus
- Importmap
- Tailwind CSS
- Dart Sass
- Octokit for GitHub API access
- Kamal for deployment

## How It Works

After GitHub sign-in, the app stores a local user record with the GitHub identity. To read repository and pull request data, the user then connects a fine-grained personal access token. That token is validated to make sure it belongs to the same GitHub account used during OAuth.

From there, the app loads the repositories visible to that token, lets the user activate the ones that matter, and fetches only the open pull requests authored by that user. Each PR is categorized into a kanban column based on whether it is a draft, approved, or has requested changes.

## Local Setup

### Requirements

- Ruby `3.2.2`
- Bundler
- PostgreSQL

### 1. Install dependencies

```bash
bundle install
```

### 2. Configure GitHub OAuth

The application expects GitHub OAuth credentials through either environment variables or Rails credentials.

Environment variables:

```bash
export GITHUB_OAUTH_CLIENT_ID="your_client_id"
export GITHUB_OAUTH_CLIENT_SECRET="your_client_secret"
```

Or Rails credentials:

- `github.oauth_client_id`
- `github.oauth_client_secret`

### 3. Prepare the database

```bash
bin/rails db:prepare
```

### 4. Start the app

```bash
bin/dev
```

That starts:

- Rails server
- Tailwind watcher
- Sass watcher

You can also use the project bootstrap script:

```bash
bin/setup
```

## GitHub OAuth Setup

The callback URL must match the app host exactly.

Default local setup:

- Base URL: `http://localhost:3000`
- Callback URL: `http://localhost:3000/auth/github/callback`

If you want to run on another origin, set `APP_BASE_URL` before starting the app:

```bash
APP_BASE_URL=http://127.0.0.1:3000 bin/dev
```

Then configure GitHub with:

```text
http://127.0.0.1:3000/auth/github/callback
```

## Fine-Grained Token Requirements

After signing in, the user must connect a fine-grained personal access token from the same GitHub account.

Recommended token setup:

- Repository access: `Only select repositories`
- Permissions:
  - `Metadata: Read-only`
  - `Pull requests: Read-only`

The app stores only the token securely, shows only the last 4 characters back to the user, and encrypts the token at rest.

## Project Structure

Main areas of the codebase:

- [app/controllers](/home/djinn/dev_dashboard/app/controllers) for authentication, repository selection, and dashboard flow
- [app/services/github](/home/djinn/dev_dashboard/app/services/github) for GitHub API integration, token validation, and PR kanban logic
- [app/views](/home/djinn/dev_dashboard/app/views) for the UI
- [app/assets/stylesheets](/home/djinn/dev_dashboard/app/assets/stylesheets) for the styling system
- [config](/home/djinn/dev_dashboard/config) for Rails, OmniAuth, deployment, and environment configuration

## Deployment

The repository already includes:

- `Dockerfile`
- Kamal configuration
- PostgreSQL accessory setup
- healthcheck endpoint at `/up`

## Testing

The project includes tests for models, controllers, and OmniAuth-related behavior.

Run them with:

```bash
bin/rails test
```
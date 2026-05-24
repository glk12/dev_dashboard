# Dev Dashboard

Rails app for tracking your GitHub pull requests with a personal fine-grained token.

## OAuth setup

The GitHub OAuth application callback URL must match the app host exactly.

- Default local base URL: `http://localhost:3000`
- OAuth callback URL: `http://localhost:3000/auth/github/callback`

If you want to run the app on a different origin, set `APP_BASE_URL` before starting Rails and use the matching callback URL in GitHub.

Example:

```bash
APP_BASE_URL=http://127.0.0.1:3000 bin/dev
```

Then configure GitHub with:

```text
http://127.0.0.1:3000/auth/github/callback
```

The app now redirects GET/HEAD requests onto the configured base URL so the login flow stays on one canonical host.

## Configuration

GitHub OAuth credentials are read from Rails credentials:

- `github.oauth_client_id`
- `github.oauth_client_secret`

## Test status

I added tests for canonical host redirects and OmniAuth host configuration, but did not run them here because `bundle` is not available in this shell.

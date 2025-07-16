#!/usr/bin/env bash
set -euo pipefail

# Script to configure GitHub repository settings for automated updates
# This enables GitHub Actions to create pull requests

echo "Configuring GitHub repository settings..."

# Get the repository name from git remote
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Repository: $REPO"

# Enable GitHub Actions to create and approve pull requests
echo "Enabling GitHub Actions to create pull requests..."

# Note: The workflow permissions setting cannot be directly set via the API
# We need to use the GitHub UI for this specific setting
# However, we can provide clear instructions

cat << EOF

================================================================
MANUAL CONFIGURATION REQUIRED
================================================================

To complete the setup, you need to manually configure the following in GitHub:

### Step 1: GitHub Actions Permissions
1. Go to: https://github.com/$REPO/settings/actions
2. Scroll down to "Workflow permissions"
3. Select: "Read and write permissions"
4. Check: "Allow GitHub Actions to create and approve pull requests"
5. Click "Save"

### Step 2: Enable Auto-Merge
1. Go to: https://github.com/$REPO/settings
2. Under "Pull Requests" section
3. Check: "Allow auto-merge"
4. Click "Save"

### Step 3: Add Cachix Auth Token (Required for Binary Caching)
1. Go to: https://github.com/$REPO/settings/secrets/actions
2. Click "New repository secret"
3. Name: CACHIX_AUTH_TOKEN
4. Value: [Your Cachix auth token for the opencode-nix cache]
5. Click "Add secret"

This will allow the automated update workflow to:
- Create pull requests for OpenCode version updates
- Update all platform hashes automatically
- Build and cache binaries via Cachix
- Automatically merge when CI passes

================================================================

After completing these steps, you can test the workflow by running:
  gh workflow run "Update OpenCode Version"

EOF

# Create a settings documentation file
echo "Creating settings documentation..."
cat > .github/REPOSITORY_SETTINGS.md << 'EOF'
# Repository Settings Configuration

This repository requires specific GitHub settings to enable automated OpenCode updates.

## Required Settings

### GitHub Actions Permissions

1. Navigate to Settings → Actions → General
2. Under "Workflow permissions":
   - Select **"Read and write permissions"**
   - Check **"Allow GitHub Actions to create and approve pull requests"**
3. Click Save

These settings allow the `update-opencode.yml` workflow to:
- Modify files in the repository
- Create pull requests for version updates
- Update platform hashes and flake.lock file

### Cachix Authentication

For binary caching to work, add the Cachix auth token:

1. Navigate to Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `CACHIX_AUTH_TOKEN`
4. Value: Your Cachix auth token for the `opencode-nix` cache
5. Click "Add secret"

This enables:
- Pushing built binaries to Cachix for fast installation
- Pulling from cache during CI/PR builds

### Auto-Merge (Optional)

To enable automatic PR merging when CI passes:

1. Navigate to Settings → General
2. Under "Pull Requests" section
3. Check **"Allow auto-merge"**
4. Click "Save"

## Workflow Overview

The repository uses three main workflows:

1. **`update-opencode.yml`** - Daily version checks, creates PRs with hash updates
2. **`build.yml`** - Builds packages and pushes to Cachix when PRs merge
3. **`test-pr.yml`** - Validates PRs with multi-platform testing

## Verification

After configuring the settings, you can verify the workflow works by:

```bash
# Manually trigger the update workflow
gh workflow run "Update OpenCode Version"

# Check the workflow status
gh run list --workflow="Update OpenCode Version"

# Test a build workflow
gh workflow run "Build and Cache"
```

## Troubleshooting

### Common Issues

**"GitHub Actions is not permitted to create or approve pull requests":**
- Ensure workflow permissions are set to "Read and write"
- Verify "Allow GitHub Actions to create and approve pull requests" is checked

**Cachix push failures:**
- Verify `CACHIX_AUTH_TOKEN` secret is set correctly
- Ensure the token has push permissions to `opencode-nix` cache

**Hash update failures:**
- Workflow may fail if OpenCode platform binaries are temporarily unavailable
- Check npm registry status for `opencode-ai` package
- Manual retry usually resolves temporary issues

### Manual Testing

To test the hash update logic manually:

```bash
# Test hash fetching for current platform
nix-prefetch-url "https://registry.npmjs.org/opencode-darwin-arm64/-/opencode-darwin-arm64-0.3.11.tgz"

# Convert to SRI format
nix hash convert --hash-algo sha256 --to sri [hash-from-above]
```

EOF

echo "✅ Setup script created!"
echo "✅ Documentation created at .github/REPOSITORY_SETTINGS.md"
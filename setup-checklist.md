# OpenCode Nix Setup Checklist

## 1. GitHub Repository Setup ✅ COMPLETED

```bash
# Already completed:
gh repo create caseymatt/opencode-nix --public --description "Nix package for OpenCode AI coding agent"
cd ~/workspace/opencode-nix
git init
git remote add origin https://github.com/caseymatt/opencode-nix.git
```

**Repository Details:**
- **URL**: https://github.com/caseymatt/opencode-nix
- **Clone Location**: `/Users/matt/workspace/opencode-nix`
- **Git Status**: Initialized with remote origin
- **GitHub CLI**: Authenticated as `caseymatt`

## 2. Cachix Setup ✅ COMPLETED

1. **Create Cachix account**: ✅ Done
2. **Create cache named**: ✅ `opencode-nix` (public)
3. **Generate auth token**: ✅ Done
4. **Add to GitHub secrets**: ✅ Done

**Cache Details:**
- **Name**: `opencode-nix`
- **Public Key**: `opencode-nix.cachix.org-1:E+dxIkUr+F0MSWES1ON1yFyOJgNRCK1XjncdbZynd2M=`
- **Auth Token**: `eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiJkOTQ5NmFkMi0zYzMxLTQ3ZTMtOTNjOC0yZjhiN2IwNzE4ZmEiLCJzY29wZXMiOiJ0eCJ9.R98oKwm3PUcOEHJM41EATvNqOKfptwV4aTLjZnJme6o`
- **Signing**: Managed by Cachix
- **Push tested**: ✅ Working

```bash
# Already completed:
cachix authtoken eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiJkOTQ5NmFkMi0zYzMxLTQ3ZTMtOTNjOC0yZjhiN2IwNzE4ZmEiLCJzY29wZXMiOiJ0eCJ9.R98oKwm3PUcOEHJM41EATvNqOKfptwV4aTLjZnJme6o
# Cache created via web UI: opencode-nix (public)
# Push capability tested and working
```

## 3. GitHub Repository Configuration

Navigate to: https://github.com/caseymatt/opencode-nix/settings

### Actions Permissions ✅ COMPLETED
- **Settings** → **Actions** → **General**
- **Workflow permissions**: ✅ Set to "Read and write permissions"
- **Allow GitHub Actions to create and approve pull requests**: ✅ Enabled
- **Actions enabled**: ✅ True for all actions

### Secrets Configuration ✅ COMPLETED
- **Settings** → **Secrets and variables** → **Actions**
- **Repository secrets**:
  - `CACHIX_AUTH_TOKEN`: ✅ Added via `gh secret set`

## 4. Initial Repository Structure

```bash
# Copy files from sadjow/claude-code-nix
cp ~/workspace/claude-code-nix/.gitignore ~/workspace/opencode-nix/
cp ~/workspace/claude-code-nix/scripts/setup-github-permissions.sh ~/workspace/opencode-nix/scripts/
cp ~/workspace/claude-code-nix/.github/REPOSITORY_SETTINGS.md ~/workspace/opencode-nix/.github/

# Create directory structure
mkdir -p ~/workspace/opencode-nix/.github/workflows
mkdir -p ~/workspace/opencode-nix/scripts
mkdir -p ~/workspace/opencode-nix/docs

# Create core files (use implementations from technical-implementation-plan.md)
touch ~/workspace/opencode-nix/flake.nix
touch ~/workspace/opencode-nix/package.nix
```

## 5. Update References in Copied Files

Update repository references in:
- `scripts/setup-github-permissions.sh`: Change repo references to `caseymatt/opencode-nix`
- `.github/REPOSITORY_SETTINGS.md`: Update URLs to point to your repository
- GitHub Actions workflows: Update cache names and repository references

## 6. Initial Commit and Push

```bash
cd ~/workspace/opencode-nix
git add .
git commit -m "Initial commit: OpenCode Nix package setup"
git push -u origin main
```

## 7. Test Setup

```bash
# Test flake builds
nix build .#opencode

# Test GitHub Actions locally (optional)
act -j build  # If you have act installed
```

## 8. Verification Checklist

- [ ] GitHub repository created at `caseymatt/opencode-nix`
- [ ] Cachix account created with `opencode-nix` cache
- [ ] GitHub Actions permissions configured
- [ ] `CACHIX_AUTH_TOKEN` secret added
- [ ] Initial files committed and pushed
- [ ] `nix build .#opencode` succeeds
- [ ] GitHub Actions workflows trigger on push
- [ ] Binary caching works (check Cachix dashboard)

## Optional: Domain Setup

If you want to create a custom domain for documentation:
- GitHub Pages can be enabled for the repository
- Custom domain can be configured (e.g., `opencode-nix.yourdomain.com`)
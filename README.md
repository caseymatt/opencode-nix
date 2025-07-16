# opencode-nix

Always up-to-date Nix package for [OpenCode](https://opencode.ai/) - AI coding agent for the terminal by SST.

**🚀 Automatically updated daily** to ensure you always have the latest OpenCode version with all platform hashes.

## Why this package?

OpenCode distributes pre-compiled native binaries through npm's platform-specific packages. This Nix package provides a clean, reproducible installation that handles:

- **Multi-platform binary management** across Linux, macOS, and Windows
- **Automated hash updates** for all 5 platform architectures  
- **Smart Home Manager integration** that respects declarative configuration
- **macOS permission persistence** via stable symlink paths

### Always Up-to-Date

This repository automatically:

- **Checks for new OpenCode versions daily** via GitHub Actions
- **Fetches and updates hashes for all platforms** (x64/arm64 across Linux/macOS/Windows)
- **Creates pull requests immediately** when updates are available
- **Provides pre-built binaries via Cachix** for instant installation

### Key Features

- **Direct Binary Distribution**: No Node.js runtime needed (75.8MB vs 169.2MB)
- **Multi-Platform Hash Management**: Automated updates for all 5 OpenCode platforms
- **Smart Home Manager Detection**: Respects declarative config when HM is present
- **macOS Permission Persistence**: Stable symlink prevents permission resets
- **Self-Contained**: Zero runtime dependencies, just the binary + minimal wrapper

## Quick Start

### Step 1: Enable Cachix (Recommended)

To get instant installation with pre-built binaries:

```bash
# Install cachix if you haven't already
nix-env -iA cachix -f https://cachix.org/api/v1/install

# Configure the opencode-nix cache
cachix use opencode-nix
```

Alternatively, add to your Nix configuration:

```nix
{
  nix.settings = {
    substituters = [ "https://opencode-nix.cachix.org" ];
    trusted-public-keys = [ "opencode-nix.cachix.org-1:PLACEHOLDER_PUBLIC_KEY" ];
  };
}
```

### Step 2: Install OpenCode

#### Direct Installation (Simplest)

```bash
# Run directly
nix run github:caseymatt/opencode-nix

# Or install to profile
nix profile install github:caseymatt/opencode-nix
```

#### Using Nix Flakes

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    opencode.url = "github:caseymatt/opencode-nix";
  };

  outputs = { self, nixpkgs, opencode, ... }: {
    # Use as an overlay
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        {
          nixpkgs.overlays = [ opencode.overlays.default ];
          environment.systemPackages = [ pkgs.opencode ];
        }
      ];
    };
  };
}
```

#### Using Home Manager (Recommended for macOS)

For automatic permission preservation and declarative management:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    opencode.url = "github:caseymatt/opencode-nix";
  };

  outputs = { self, nixpkgs, home-manager, opencode, ... }: {
    homeConfigurations."username" = home-manager.lib.homeManagerConfiguration {
      modules = [
        {
          nixpkgs.overlays = [ opencode.overlays.default ];
          
          # Install OpenCode
          home.packages = [ pkgs.opencode ];
          
          # Optional: Manage stable symlink declaratively (for macOS permission persistence)
          home.file.".local/bin/opencode".source = 
            config.lib.file.mkOutOfStoreSymlink "${pkgs.opencode}/bin/opencode";
            
          # Optional: Preserve OpenCode configuration
          home.file.".opencode".source = config.lib.file.mkOutOfStoreSymlink 
            "${config.home.homeDirectory}/.opencode";
        }
      ];
    };
  };
}
```

## Usage Scenarios

### For Home Manager Users

OpenCode automatically detects Home Manager and skips auto-symlink creation, giving you full declarative control:

```nix
{
  # Install OpenCode
  home.packages = [ opencode.packages.${pkgs.system}.default ];
  
  # Manage stable symlink declaratively (for macOS permission persistence)
  home.file.".local/bin/opencode".source = 
    config.lib.file.mkOutOfStoreSymlink "${opencode.packages.${pkgs.system}.default}/bin/opencode";
}
```

### For Non-Home Manager Users

Simply install and run - symlinks are created automatically for convenience:

```bash
nix profile install github:caseymatt/opencode-nix
opencode --version  # Symlink created automatically on first run (macOS)
```

## Development

```bash
# Clone the repository
git clone https://github.com/caseymatt/opencode-nix
cd opencode-nix

# Build the package
nix build

# Run tests
nix run . -- --version

# Enter development shell
nix develop
```

## Automated Updates

### How It Works

This repository uses a sophisticated automated update system:

1. **Daily Version Check**: GitHub Actions checks npm registry for new `opencode-ai` versions
2. **Multi-Platform Hash Fetching**: Downloads and hashes all 5 platform binaries
3. **Atomic Updates**: Creates PR with version + all platform hashes updated together
4. **Build Validation**: Tests build on Linux and macOS before auto-merge
5. **Cachix Push**: Successful builds are cached for instant user installation

### Workflow Overview

Three main workflows handle automation:

- **`update-opencode.yml`** - Daily version checks, creates PRs with hash updates
- **`build.yml`** - Builds packages and pushes to Cachix when PRs merge  
- **`test-pr.yml`** - Validates PRs with comprehensive multi-platform testing

### Manual Updates

To manually update to a newer version:

1. Edit `package.nix` and change the `version` field
2. Update platform hashes in the `platformHashes` section
3. Build and test locally: `nix build && ./result/bin/opencode --version`
4. Update `flake.lock`: `nix flake update`
5. Submit a pull request

## Architecture Details

### Binary Distribution Approach

Unlike traditional npm packages, OpenCode uses platform-specific binary packages:

```
opencode-ai@0.3.11 (meta package)
├── opencode-darwin-arm64@0.3.11 (75.8MB binary)
├── opencode-darwin-x64@0.3.11   (binary)
├── opencode-linux-x64@0.3.11    (binary)  
├── opencode-linux-arm64@0.3.11  (binary)
└── opencode-windows-x64@0.3.11  (binary)
```

This Nix package:
1. Detects your platform automatically
2. Downloads the correct platform-specific binary
3. Creates a minimal wrapper for environment setup
4. Provides stable paths for permission persistence

### Smart Home Manager Integration

The package includes runtime detection that:

```bash
# Detects Home Manager via multiple indicators
if [[ -n "$__HM_SESS_VARS_SOURCED" ]] || \
   [[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
  # Home Manager detected - let it manage symlinks declaratively
else
  # No Home Manager - provide convenience auto-creation
  ln -sf "$out/bin/opencode" "$HOME/.local/bin/opencode"
fi
```

This ensures compatibility with both declarative (HM) and imperative usage patterns.

## Troubleshooting

### OpenCode asks for permissions after every update (macOS)

This package includes automatic fixes for permission persistence:

1. **Non-HM users**: Symlink to `~/.local/bin/opencode` is created automatically
2. **HM users**: Add the symlink to your `home.nix` configuration (see examples above)
3. Ensure you run `opencode` from the stable path, not the nix store path

### Build failures with hash mismatches

If you see hash mismatch errors:

1. Check if OpenCode released a new version recently
2. Platform binaries might still be propagating to npm CDN
3. Wait a few minutes and retry, or manually trigger the update workflow

### Home Manager conflicts

If you see symlink conflicts:

1. Remove `home.file.".local/bin/opencode"` from your HM config temporarily  
2. Run `home-manager switch`
3. The package will auto-detect HM is active and skip auto-creation

### Manual testing of platform hashes

```bash
# Test hash fetching for your platform
nix-prefetch-url "https://registry.npmjs.org/opencode-darwin-arm64/-/opencode-darwin-arm64-0.3.11.tgz"

# Convert to SRI format
nix hash convert --hash-algo sha256 --to sri [hash-from-above]
```

## Migration Guide

### From npm global installation

```bash
# Remove npm version
npm uninstall -g opencode-ai

# Install via Nix
nix profile install github:caseymatt/opencode-nix

# Your ~/.config/opencode configuration is preserved
```

### From Homebrew installation  

```bash
# Remove Homebrew version
brew uninstall opencode

# Install via Nix  
nix profile install github:caseymatt/opencode-nix
```

### From manual installation

```bash
# Remove manual installation
rm -rf ~/.opencode

# Install via Nix
nix profile install github:caseymatt/opencode-nix

# Restore your backed up config if needed
```

## Repository Setup

For contributors and forkers, see:

- [Repository Settings Guide](.github/REPOSITORY_SETTINGS.md) - Required GitHub settings
- [Symlink and Home Manager Integration](docs/symlink-and-home-manager-integration.md) - Design decisions
- [Technical Implementation Plan](docs/technical-implementation-plan.md) - Full architecture

Run the setup script to configure GitHub repository permissions:

```bash
./scripts/setup-github-permissions.sh
```

## License

The Nix packaging is MIT licensed. OpenCode itself is proprietary software by SST (sst.dev).
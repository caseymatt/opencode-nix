# OpenCode Nix Package - Technical Implementation Plan

## Architecture Overview

**IMPORTANT: OpenCode vs Claude Code Architectural Differences**

Unlike Claude Code (which is a Node.js application), OpenCode distributes **pre-compiled native binaries** through npm. This fundamentally changes our Nix packaging approach:

### Claude Code Architecture:
- **Type**: Node.js application (169.2MB npm package)
- **Runtime**: Requires Node.js to execute `node cli.js`
- **Dependencies**: Node.js + npm modules
- **Installation**: `npm install` → Node.js modules

### OpenCode Architecture:
- **Type**: Pre-compiled native binary (75.8MB)
- **Runtime**: Self-contained executable
- **Dependencies**: System libraries only (`libicucore.A.dylib`, `libresolv.9.dylib`, etc.)
- **Installation**: `npm install` → Downloads platform-specific binary

**Our Nix package approach:**
1. Downloads OpenCode platform-specific binary during build
2. ~~Bundles required runtimes~~ **NOT NEEDED** (binary is self-contained)
3. Creates minimal wrapper script for consistent path handling
4. Provides automated updates via GitHub Actions
5. Integrates with Cachix for binary distribution

## Project Structure

```
opencode-nix/
├── flake.nix                        # Main flake definition
├── flake.lock                       # Dependency lockfile
├── package.nix                      # Core package definition
├── scripts/
│   └── setup-github-permissions.sh  # GitHub configuration helper
├── .github/workflows/
│   ├── update-opencode.yml          # Daily version checking
│   ├── build.yml                    # Build and cache on push/PR
│   └── test-pr.yml                  # PR testing workflow
└── docs/
    ├── problem-description.md       # High-level overview
    └── technical-implementation-plan.md
```

## Core Components

### 1. Package Definition (`package.nix`)

**Adapted from `sadjow/claude-code-nix/package.nix`:**

```nix
{ lib, stdenv, fetchurl, cacert, bash, system }:

let
  # Platform detection matching npm's optionalDependencies
  platformName = {
    "x86_64-linux" = "opencode-linux-x64";
    "aarch64-linux" = "opencode-linux-arm64";
    "x86_64-darwin" = "opencode-darwin-x64";
    "aarch64-darwin" = "opencode-darwin-arm64";
    "x86_64-windows" = "opencode-windows-x64";
  }.${system} or (throw "Unsupported system: ${system}");
in

stdenv.mkDerivation rec {
  pname = "opencode";
  version = "0.3.11";  # Update this to install a newer version

  # Download platform-specific binary directly
  src = fetchurl {
    url = "https://registry.npmjs.org/${platformName}/-/${platformName}-${version}.tgz";
    sha256 = lib.fakeSha256;  # Will be updated with actual hash during build
  };

  # Build dependencies - SIMPLIFIED for binary distribution
  nativeBuildInputs = [ 
    cacert      # SSL certificates for npm/binary downloads
    bash        # For wrapper scripts
  ];
  
  # No runtime dependencies needed - binary is self-contained
  # buildInputs = [];  # Empty - no runtime deps needed
  
  buildPhase = ''
    # Extract the platform-specific binary tarball
    tar -xzf $src
    
    # The binary is located at: package/bin/opencode (or opencode.exe on Windows)
    # Verify the binary exists and is executable
    if [ ! -f package/bin/opencode ]; then
      echo "Error: Expected binary not found in package/bin/opencode"
      exit 1
    fi
    
    # Verify it's actually a binary and not a script
    file package/bin/opencode
  '';

  installPhase = ''
    # Install the binary directly
    mkdir -p $out/bin
    cp package/bin/opencode $out/bin/opencode
    chmod +x $out/bin/opencode
    
    # Create a minimal wrapper script for:
    # 1. Consistent executable path (prevents macOS permission resets)
    # 2. Update interception (prevent auto-updates)
    # 3. Clean environment
    
    # Rename the actual binary
    mv $out/bin/opencode $out/bin/opencode-bin
    
    # Create wrapper script
    cat > $out/bin/opencode << 'EOF'
    #!${bash}/bin/bash
    
    # Set a consistent executable path for OpenCode to prevent permission resets
    # This makes macOS and OpenCode think it's always the same binary
    export OPENCODE_EXECUTABLE_PATH="$HOME/.local/bin/opencode"
    
    # Disable automatic update checks since updates should go through Nix
    export DISABLE_AUTOUPDATER=1
    
    # Execute the actual binary with all arguments
    exec "$out/bin/opencode-bin" "$@"
    EOF
    chmod +x $out/bin/opencode
    
    # Replace $out placeholder with the actual output path
    substituteInPlace $out/bin/opencode \
      --replace '$out' "$out"
  '';

  meta = with lib; {
    description = "OpenCode - AI coding agent for the terminal";
    homepage = "https://opencode.ai/";
    platforms = platforms.all;
  };
}
```

**Key Adaptations from Claude Code:**
- **Simplified Dependencies**: No runtime dependencies (vs Claude Code's Node.js requirement)
- **Binary Distribution**: Direct platform-specific binary (vs Claude Code's npm modules)
- **Minimal Wrapper**: Simple binary execution (vs Claude Code's complex Node.js wrapper)
- **Package Source**: `opencode-{platform}-{arch}` binaries instead of `@anthropic-ai/claude-code`

### 2. Binary Wrapper (SIMPLIFIED)

**No Runtime Management Needed:**
Since OpenCode distributes pre-compiled binaries, we don't need runtime orchestration:

```bash
# Minimal wrapper script responsibilities:
export OPENCODE_EXECUTABLE_PATH="$HOME/.local/bin/opencode"
export DISABLE_AUTOUPDATER=1

# Direct binary execution - no runtime detection needed
exec "$out/bin/opencode-bin" "$@"
```

**Key Features:**
- **No Runtime Dependencies**: Binary is self-contained
- **Path Management**: Consistent executable paths for permission persistence
- **Update Interception**: Disable auto-updater (no npm wrapper needed)
- **Minimal Overhead**: Direct binary execution with environment setup

### 3. Permission Persistence (macOS)

**Stable Binary Strategy:**
```bash
# Create consistent executable path
export OPENCODE_EXECUTABLE_PATH="$HOME/.local/bin/opencode"

# Ensure stable symlink exists
mkdir -p "$HOME/.local/bin"
ln -sf "$out/bin/opencode" "$HOME/.local/bin/opencode"
```

**Home Manager Integration:**
```nix
# In home.nix
home.file.".local/bin/opencode".source = 
  config.lib.file.mkOutOfStoreSymlink "${opencode-package}/bin/opencode";

# Preserve OpenCode configuration
home.file.".opencode".source = config.lib.file.mkOutOfStoreSymlink 
  "${config.home.homeDirectory}/.opencode";
```

### 4. Automated Updates

**GitHub Actions Workflow (`update-opencode.yml`):**
```yaml
name: Update OpenCode Version
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight UTC
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Check for new OpenCode version
        id: version-check
        run: |
          CURRENT=$(grep 'version = ' package.nix | cut -d'"' -f2)
          LATEST=$(npm view opencode-ai version)
          
          if [ "$CURRENT" != "$LATEST" ]; then
            echo "update-needed=true" >> $GITHUB_OUTPUT
            echo "new-version=$LATEST" >> $GITHUB_OUTPUT
          fi
      
      - name: Update package.nix
        if: steps.version-check.outputs.update-needed == 'true'
        run: |
          sed -i 's/version = ".*"/version = "${{ steps.version-check.outputs.new-version }}"/' package.nix
          
      - name: Update flake.lock
        if: steps.version-check.outputs.update-needed == 'true'
        run: nix flake update
        
      - name: Create Pull Request
        if: steps.version-check.outputs.update-needed == 'true'
        id: create-pr
        uses: peter-evans/create-pull-request@v6
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          title: "chore: update OpenCode to ${{ steps.version-check.outputs.new-version }}"
          commit-message: "chore: update OpenCode to ${{ steps.version-check.outputs.new-version }}"
          body: |
            ## Automated OpenCode Update
            
            Updates OpenCode from `${{ steps.version-check.outputs.current-version }}` to `${{ steps.version-check.outputs.new-version }}`.
            
            ### Changes
            - Updated `version` in `package.nix`
            - Updated `flake.lock` with new derivation hash
            
            ### Verification Checklist
            - [ ] Version number is correctly updated in `package.nix`
            - [ ] `flake.lock` has been updated
            - [ ] The new version builds successfully
            - [ ] Binary functionality works as expected
            - [ ] Basic OpenCode functionality works as expected
            
            ---
            
            To test this update locally:
            ```bash
            nix build .#opencode
            ./result/bin/opencode --version
            ```
            
            This PR was automatically generated by the update workflow.
          branch: update-opencode-${{ steps.version-check.outputs.new-version }}
          delete-branch: true
          labels: |
            dependencies
            automated
      
      - name: Enable Auto-Merge
        if: steps.version-check.outputs.update-needed == 'true' && steps.create-pr.outputs.pull-request-number
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh pr merge ${{ steps.create-pr.outputs.pull-request-number }} --auto --squash --delete-branch
```

**Version Monitoring Strategy:**
- **Source**: npm registry for `opencode-ai` package
- **Frequency**: Daily automated checks at midnight UTC
- **Validation**: Automated build and basic functionality tests
- **Auto-merge**: Enabled with build validation safeguards
- **Rollback**: Previous version available via Nix generations

**Automation Process (adapted from `sadjow/claude-code-nix`):**
1. **Daily Check**: GitHub Actions runs at midnight UTC
2. **Version Comparison**: Compares `package.nix` version vs npm registry
3. **Auto-PR**: Creates PR with version update + flake.lock update
4. **Build Validation**: `build.yml` workflow tests each PR before merge
5. **Auto-Merge**: Uses `gh pr merge --auto --squash` if tests pass

**Edge Cases & Safeguards:**
- **Build Failures**: Auto-merge blocked until tests pass
- **npm Package Changes**: Build tests catch structural changes
- **Network Issues**: Workflow skips check if npm registry unavailable
- **Concurrent Updates**: Branch naming prevents conflicts
- **Enhanced Testing**: Binary validation and functionality testing

**Risk Mitigation:**
- **Proven Pattern**: 8 consecutive successful auto-merges in `sadjow/claude-code-nix`
- **Build Validation**: Comprehensive testing before auto-merge
- **Easy Rollback**: Nix generations enable instant rollback
- **GitHub Notifications**: Failed builds create GitHub notifications

### 5. Build and Testing (`build.yml`)

**Adapted from `sadjow/claude-code-nix/.github/workflows/build.yml`:**

```yaml
name: "Build and Cache"

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:
  workflow_run:
    workflows: ["Update OpenCode Version"]
    types: [completed]

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        include:
          - os: ubuntu-latest
            system: x86_64-linux
          - os: macos-latest
            system: aarch64-darwin
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Install Nix
      uses: cachix/install-nix-action@v24
      with:
        nix_path: nixpkgs=channel:nixos-unstable
    
    - name: Setup Cachix
      uses: cachix/cachix-action@v14
      with:
        name: opencode-nix
        authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
    
    - name: Build opencode
      run: |
        nix build .#opencode --print-build-logs
        
    - name: Test opencode functionality
      run: |
        # Test basic functionality
        ./result/bin/opencode --version
        
        # Test wrapper script permissions
        test -x ./result/bin/opencode
        
        # Verify binary structure
        test -f ./result/bin/opencode
        test -f ./result/bin/opencode-bin
        
    - name: Test on macOS permission paths
      if: matrix.os == 'macos-latest'
      run: |
        # Test stable binary path creation
        mkdir -p ~/.local/bin
        ln -sf ./result/bin/opencode ~/.local/bin/opencode
        ~/.local/bin/opencode --version
        
    - name: Push to Cachix
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      run: |
        nix build .#opencode
        cachix push opencode-nix result
```

**Key Adaptations from Claude Code:**
- **Binary Testing**: Tests single binary functionality and version
- **Enhanced Validation**: Verifies OpenCode-specific binary structure
- **Permission Testing**: macOS-specific stable path validation
- **Cachix Integration**: Binary caching for faster installation

### 6. Flake Definition (`flake.nix`)

**Adapted from `sadjow/claude-code-nix/flake.nix`:**

```nix
{
  description = "OpenCode - AI coding agent for the terminal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Overlay for integration with other flakes
      overlay = final: prev: {
        opencode = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.opencode;
          opencode = pkgs.opencode;
        };
        
        # App definition for `nix run`
        apps = {
          default = {
            type = "app";
            program = "${pkgs.opencode}/bin/opencode";
          };
        };

        # Development shell with minimal required tools
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt    # Nix code formatting
            nix-prefetch-git # For updating dependencies
            cachix         # For binary caching
            gh             # GitHub CLI for automation
          ];
        };
      }) // {
        # Export overlay for use in other flakes
        overlays.default = overlay;
      };
}
```

**Key Adaptations from Claude Code:**
- **Simplified Development**: No runtime dependencies needed in dev shell
- **Enhanced Tooling**: Added `gh` for GitHub automation
- **OpenCode Branding**: Updated descriptions and package names
- **No License Restrictions**: Removed `allowUnfree` (OpenCode binary distribution is different)

## Installation and Usage

### Direct Installation
```bash
# Install from GitHub
nix profile install github:caseymatt/opencode-nix

# Run OpenCode
opencode
```

### Home Manager Integration
```nix
# In flake.nix
inputs.opencode.url = "github:caseymatt/opencode-nix";

# In home.nix
{ config, pkgs, opencode, ... }:
{
  home.packages = [
    opencode.packages.${pkgs.system}.default
  ];
}
```

### Development Environment
```bash
# Clone and develop
git clone https://github.com/caseymatt/opencode-nix
cd opencode-nix
nix develop

# Test build
nix build .#opencode
```

## Starter Scaffolding from `sadjow/claude-code-nix`

### Files to Copy and Adapt:

1. **`.gitignore`** - Use as-is from `sadjow/claude-code-nix`
2. **`flake.lock`** - Copy and update via `nix flake update`
3. **`scripts/setup-github-permissions.sh`** - Copy and update repo references
4. **`.github/REPOSITORY_SETTINGS.md`** - Copy and update repo references
5. **`README.md`** - Copy structure and adapt for OpenCode

### GitHub Actions Workflows to Copy:

1. **`test-pr.yml`** - Copy from `sadjow/claude-code-nix/.github/workflows/test-pr.yml`
2. **`build.yml`** - Adapt as shown above
3. **`update-claude-code.yml`** - Rename to `update-opencode.yml` and adapt package references

### Additional Files Needed:

```bash
# Essential starter files to create:
touch flake.nix           # Use adapted version above
touch package.nix         # Use adapted version above
mkdir -p .github/workflows
mkdir -p scripts
mkdir -p docs
```

## Implementation Phases

### Phase 1: Core Package (Week 1)
- [ ] Copy and adapt `flake.nix` from `sadjow/claude-code-nix`
- [ ] Create `package.nix` with **version 0.3.11** and **simplified binary architecture** (no runtime bundling needed)
- [ ] Copy `.gitignore` and basic project structure
- [ ] Test basic build functionality with `nix build`

### Phase 2: Binary Wrapper (Week 2)
- [ ] Implement **minimal wrapper script** for path consistency (as shown in adapted `package.nix`)
- [ ] Add stable binary path management for macOS permission persistence
- [ ] Create update interception system (environment variables only)
- [ ] Test binary execution and path handling

### Phase 3: Automation (Week 3)
- [ ] Copy and adapt GitHub Actions workflows (`build.yml`, `test-pr.yml`, `update-opencode.yml`)
- [ ] Set up Cachix integration for binary distribution
- [ ] Configure automated version checking for `opencode-ai` npm package
- [ ] Add comprehensive testing suite with **binary validation** (no multi-runtime testing needed)

### Phase 4: Integration (Week 4)
- [ ] Add Home Manager integration examples
- [ ] Implement macOS permission persistence (stable binary paths)
- [ ] Copy and adapt documentation from `sadjow/claude-code-nix`
- [ ] Performance optimization and comprehensive testing
- [ ] Create migration guide from existing OpenCode installations

## Risk Mitigation

**Binary Distribution Complexity:**
- Risk: Platform-specific binary availability or compatibility issues
- Mitigation: Comprehensive testing matrix across platforms, fallback mechanisms

**npm Registry Dependency:**
- Risk: OpenCode package availability or structure changes
- Mitigation: Version pinning, automated testing, manual override capability

**Permission Management:**
- Risk: macOS permission changes break functionality
- Mitigation: Stable path strategy, comprehensive testing on macOS

**Update Automation:**
- Risk: Automated updates introduce breaking changes
- Mitigation: Staged rollout, automated testing, easy rollback

## Success Criteria

1. **One-command installation** across all platforms
2. **Zero-touch updates** with automated testing
3. **No permission resets** on macOS
4. **Complete runtime isolation** from project environments
5. **Sub-30-second installation** via Cachix
6. **100% reproducible builds** across environments

This implementation plan provides a robust foundation for OpenCode Nix package that solves real-world deployment challenges while maintaining the simplicity and reliability that Nix users expect.
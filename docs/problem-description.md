# OpenCode Nix Package - Problem Description

## Overview

**opencode-nix** is a Nix package for managing OpenCode installation that provides reproducible, version-controlled deployment of the OpenCode AI coding agent while solving common runtime dependency conflicts.

## What is OpenCode?

OpenCode is an AI coding agent built for the terminal by SST (sst.dev). It provides:
- Native terminal UI (TUI) that is responsive and themeable
- LSP (Language Server Protocol) support
- Multiple parallel coding sessions
- Shareable session links
- Support for 75+ LLM providers (Claude, OpenAI, Google, local models)
- Provider-agnostic architecture

## The Problem

### 1. Binary Distribution vs Runtime Dependencies

**IMPORTANT: OpenCode's Actual Architecture**

OpenCode uses a **binary distribution model** different from traditional npm packages:

**Development Architecture (GitHub repo):**
- **Bun** (JavaScript runtime) for development
- **Go 1.24.x** for core functionality (52.6% of codebase)
- **Node.js ecosystem** for TypeScript components (40.6% of codebase)

**Distribution Architecture (npm package):**
- **Pre-compiled native binaries** (75.8MB per platform)
- **Platform-specific packages**: `opencode-darwin-arm64`, `opencode-linux-x64`, etc.
- **No runtime dependencies** - binaries are self-contained
- **npm wrapper** downloads and manages platform-specific binaries

**Current Installation Issues:**
- npm installation can fail due to platform-specific package availability
- Binary permissions and paths change between updates
- No unified approach across different systems
- Update mechanisms bypass package managers

### 2. Inconsistent Installation Methods

OpenCode currently supports multiple installation methods:
- `npm i -g opencode-ai@latest`
- `curl -fsSL https://opencode.ai/install | bash`
- `brew install sst/tap/opencode`
- `paru -S opencode-bin` (Arch Linux)

**Problems:**
- No unified approach across different systems
- Each method has different dependency assumptions
- Updates require manual intervention
- Permission and configuration persistence varies by method

### 3. macOS Permission Issues

Similar to other AI coding tools, OpenCode faces macOS permission challenges:
- App permissions reset after binary updates
- Accessibility and file system access permissions lost
- Users must re-grant permissions after each update
- Inconsistent binary paths trigger permission resets

### 4. Update Management

Current update mechanisms are fragmented:
- Manual updates through different package managers
- No automated version checking
- Risk of version drift across development environments
- No rollback capabilities for problematic updates

## The Solution: Nix Package Approach

### Core Benefits

1. **Simplified Binary Management**
   - Direct platform-specific binary installation (no runtime bundling needed)
   - Consistent binary paths regardless of project environment
   - No version manager conflicts since binary is self-contained

2. **Reproducible Installation**
   - Declarative package definition
   - Pinned binary versions via `flake.lock`
   - Identical installation across all machines

3. **Automated Updates**
   - GitHub Actions monitoring OpenCode releases
   - Automated pull requests for version updates
   - Consistent update testing and validation

4. **Permission Persistence**
   - Stable binary paths to prevent permission resets
   - Integration with Home Manager for configuration preservation
   - Consistent executable locations across updates

5. **Rollback Capabilities**
   - Easy reversion to previous versions
   - Atomic updates with rollback support
   - Generation-based version management

### Architecture Inspiration

Following the proven patterns from **sadjow/claude-code-nix** (adapted for binary distribution):
- Daily automated version checking
- ~~Bundled runtime approach~~ **Direct binary distribution**
- ~~Custom wrapper scripts for runtime management~~ **Minimal wrapper for path consistency**
- Cachix integration for fast binary distribution
- Home Manager integration for declarative configuration

## Target Users

- **Nix/NixOS users** seeking declarative OpenCode management
- **Development teams** requiring consistent OpenCode versions
- **DevOps engineers** managing reproducible development environments
- **macOS users** frustrated with permission management
- **Multi-project developers** avoiding version manager conflicts

## Success Metrics

- **Installation reliability**: Single command installation across all supported platforms
- **Update automation**: Zero-touch updates with automated testing
- **Permission persistence**: No permission re-grants after updates
- **Runtime isolation**: No conflicts with project-specific toolchains
- **Binary availability**: Pre-built binaries via Cachix for instant installation

This approach transforms OpenCode from a complex multi-runtime installation into a simple, reproducible Nix package that "just works" across all development environments.
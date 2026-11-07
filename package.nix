{ lib, stdenv, fetchurl, cacert, bash, unzip, system }:

let
  # Platform detection and corresponding hashes
  # These hashes are automatically updated by GitHub Actions
  platformHashes = {
    "x86_64-linux" = "sha256-CLsh1jJs50DZHM5+voimU2kz9uHjA1O5GgawHyXaMGw=";
    "aarch64-linux" = "sha256-8tJ2AMNn5FBX1qFvalwqqNd7QamxDUvD2EnC+Ihw6UQ=";
    "x86_64-darwin" = "sha256-spYtxEXYc99Wrn07p+ZlArBGu8Ta+oIOyhjQMDqYopw=";
    "aarch64-darwin" = "sha256-FUkWCPawvE3r5erDXqtimisH6pofusaK1TvOpZ/MS0U=";
    "x86_64-windows" = "sha256-91wWszuFI/4f9B59l+OuZUpH1ZoOMn3vJNstkpG7JL4=";
  };

  # OpenCode 2.x is published as GitHub release archives, not on npm
  platformAssets = {
    "x86_64-linux" = "opencode-linux-x64.tar.gz";
    "aarch64-linux" = "opencode-linux-arm64.tar.gz";
    "x86_64-darwin" = "opencode-darwin-x64.zip";
    "aarch64-darwin" = "opencode-darwin-arm64.zip";
    "x86_64-windows" = "opencode-windows-x64.zip";
  };

  platformAsset = platformAssets.${system} or (throw "Unsupported system: ${system}");
  platformHash = platformHashes.${system} or (throw "Unsupported system: ${system}");
in

stdenv.mkDerivation rec {
  pname = "opencode";
  version = "2.2.6";  # Update this to install a newer version

  # Download platform-specific binary directly
  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/${platformAsset}";
    sha256 = platformHash;
  };

  # Build dependencies - SIMPLIFIED for binary distribution
  nativeBuildInputs = [ 
    cacert      # SSL certificates for npm/binary downloads
    bash        # For wrapper scripts
    unzip       # Darwin and Windows release archives are zips
  ];

  dontUnpack = true;
  # Bun-compiled binaries carry an embedded payload that strip can corrupt
  dontStrip = true;
  
  # No runtime dependencies needed - binary is self-contained
  # buildInputs = [];  # Empty - no runtime deps needed
  
  buildPhase = ''
    # Each release archive holds a single binary named opencode
    mkdir -p package/bin
    case "$src" in
      *.zip) unzip -q $src -d package/bin ;;
      *) tar -xzf $src -C package/bin ;;
    esac

    if [ ! -f package/bin/opencode ]; then
      echo "Error: Expected binary not found in release archive"
      exit 1
    fi
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

# Create stable symlink for macOS permission persistence
# This ensures the same path is always used, preventing permission resets
if [[ "$OSTYPE" == "darwin"* ]]; then
  mkdir -p "$HOME/.local/bin"
  
  # Check if Home Manager is managing this environment
  if [[ -n "$__HM_SESS_VARS_SOURCED" ]] || \
     [[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]] || \
     [[ -f "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh" ]]; then
    # Home Manager detected - let it manage symlinks declaratively
    : # no-op
  else
    # No Home Manager - provide convenience auto-creation
    if [[ ! -e "$HOME/.local/bin/opencode" ]]; then
      ln -sf "$out/bin/opencode" "$HOME/.local/bin/opencode"
    fi
  fi
fi

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

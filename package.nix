{ lib, stdenv, fetchurl, cacert, bash, system }:

let
  # Platform detection and corresponding hashes
  # These hashes are automatically updated by GitHub Actions
  platformHashes = {
    "x86_64-linux" = "sha256-tYTAGDD9AnB3vSYO9Guo1A3AF0sOCdCJfNU3Gml7UG8=";
    "aarch64-linux" = "sha256-JmzODTMVRzVcoIghUMGwmiCgc+Lsz35b7rJdV49Xpl4=";
    "x86_64-darwin" = "sha256-p26sZAsy0tSniWEGmeJyhI+bjyBEU5RWP7+Ad+gS5ec=";
    "aarch64-darwin" = "sha256-0j5yaHuUWOPZfd5aJZ02KEg3aH2D8+Mhg76KFDgr3oo=";
    "x86_64-windows" = "sha256-t92CCElOgn1Yr9kT/p4BANYSz9ssuqya/7jQ3728z8Y=";
  };

  platformNames = {
    "x86_64-linux" = "opencode-linux-x64";
    "aarch64-linux" = "opencode-linux-arm64";
    "x86_64-darwin" = "opencode-darwin-x64";
    "aarch64-darwin" = "opencode-darwin-arm64";
    "x86_64-windows" = "opencode-windows-x64";
  };

  platformName = platformNames.${system} or (throw "Unsupported system: ${system}");
  platformHash = platformHashes.${system} or (throw "Unsupported system: ${system}");
in

stdenv.mkDerivation rec {
  pname = "opencode";
  version = "1.1.4";  # Update this to install a newer version

  # Download platform-specific binary directly
  src = fetchurl {
    url = "https://registry.npmjs.org/${platformName}/-/${platformName}-${version}.tgz";
    sha256 = platformHash;
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

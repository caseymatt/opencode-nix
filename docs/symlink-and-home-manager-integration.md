# Symlink and Home Manager Integration

## Overview

This document explains the design decisions and implementation details for OpenCode's stable symlink creation and Home Manager integration. The implementation addresses macOS permission persistence while respecting Home Manager's declarative philosophy.

## The Problem: macOS Permission Resets

### What Happens Without Stable Paths

On macOS, when you grant permissions to an application (Terminal access, File system access, etc.), macOS remembers the **exact file path** to the binary. With Nix, this creates a problem:

1. **Nix store paths change between updates**:
   - Old: `/nix/store/abc123-opencode-0.3.11/bin/opencode`
   - New: `/nix/store/def456-opencode-0.3.12/bin/opencode`

2. **macOS treats these as different applications**:
   - "This binary path doesn't match our records"
   - All permissions are reset to default (denied)

3. **User frustration**:
   - Must re-grant permissions after every OpenCode update
   - Interrupts workflow with permission dialogs

### The Stable Symlink Solution

Create a **stable path** that always points to the current OpenCode version:

```bash
~/.local/bin/opencode -> /nix/store/current-version/bin/opencode
```

**How it works**:
1. OpenCode sets `OPENCODE_EXECUTABLE_PATH="$HOME/.local/bin/opencode"`
2. OpenCode reports this stable path to macOS for permission requests
3. When we update OpenCode, we update where the symlink points
4. macOS still sees the same path → **permissions persist!**

## The Home Manager Consideration

### Two Types of Nix Users

**Home Manager Users**:
- Want **declarative control** over their environment
- Expect explicit configuration in `home.nix`
- Don't want applications auto-creating files in `$HOME`
- Prefer to manage symlinks declaratively

**Non-Home Manager Users**:
- Want things to "just work" out of the box
- Benefit from convenience features
- Less concerned about declarative vs imperative approaches

### The Conflict

Without proper handling, both approaches could fight over symlink management:

```bash
# Runtime auto-creation (our wrapper)
ln -sf "$out/bin/opencode" "$HOME/.local/bin/opencode"

# Home Manager declarative (user's home.nix)
home.file.".local/bin/opencode".source = 
  config.lib.file.mkOutOfStoreSymlink "${opencode-package}/bin/opencode";
```

**Potential issues**:
- Home Manager creates symlink declaratively
- User removes it from HM config
- HM removes the symlink on next switch
- OpenCode recreates it automatically
- Next `home-manager switch` complains about existing file

## Our Solution: Smart Detection

### Implementation Approach

We implement **runtime detection** in the wrapper script that determines whether Home Manager is managing the environment and adjusts behavior accordingly.

```bash
# Create stable symlink for macOS permission persistence
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
```

### Home Manager Detection Methods

Based on established Nix community practices, we use these detection methods in order of reliability:

1. **`__HM_SESS_VARS_SOURCED` environment variable**
   - Most reliable runtime indicator
   - Set to `1` when Home Manager session variables are active

2. **Session variables file existence**
   - `~/.nix-profile/etc/profile.d/hm-session-vars.sh`
   - `/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh`
   - More reliable than checking config files

### Design Principles

**Priority: Home Manager users first**
- Respect declarative philosophy when HM is detected
- Provide convenience for non-HM users
- Clear separation of approaches

**Graceful behavior**:
- No conflicts between management approaches
- Clear documentation for both use cases
- Fallback convenience when HM not present

## Usage Scenarios

### For Home Manager Users

Add to your `home.nix`:

```nix
{
  # Install OpenCode
  home.packages = [ opencode.packages.${pkgs.system}.default ];
  
  # Manage stable symlink declaratively (for macOS permission persistence)
  home.file.".local/bin/opencode".source = 
    config.lib.file.mkOutOfStoreSymlink "${opencode.packages.${pkgs.system}.default}/bin/opencode";
}
```

**What happens**:
- OpenCode detects Home Manager is active
- Skips automatic symlink creation
- User has full declarative control

### For Non-Home Manager Users

Simply install and run:

```bash
nix profile install github:caseymatt/opencode-nix
opencode --version  # Symlink created automatically on first run
```

**What happens**:
- OpenCode detects no Home Manager
- Creates symlink automatically for convenience
- User gets working permissions without manual setup

## Technical Details

### When Detection Happens

**Build Time** (GitHub Actions/Cachix):
- `package.nix` creates the wrapper script with detection logic
- No actual detection happens during build
- Detection logic is embedded in the wrapper for runtime execution

**Runtime** (User's Machine):
- Wrapper script executes detection when user runs `opencode`
- Checks user's actual environment for Home Manager indicators
- Makes symlink decision based on user's setup

### Cross-Platform Behavior

**macOS**: Full symlink management (where permissions matter most)
**Linux**: Same logic for consistency, though less critical for permissions
**Windows**: Logic present but symlinks less relevant in Windows context

### Edge Cases Handled

1. **User removes symlink manually**: Respects choice, doesn't recreate
2. **HM user removes symlink from config**: No auto-recreation, avoids conflicts
3. **Mixed environments**: Detection works per-machine, not globally
4. **Non-standard HM setups**: Multiple detection methods increase reliability

## Research and Best Practices

This implementation follows established patterns from the Nix community:

### Community Research Findings

- Very few nixpkgs packages explicitly detect Home Manager
- Most delegate user file management entirely to HM modules
- Community preference: convenience for newcomers, declarative control for advanced users
- Graceful degradation preferred over hard requirements

### Detection Pattern Source

The detection logic follows patterns found in:
- Home Manager's own session variable management
- Other packages handling conditional user environment setup
- Community discussions about "should I manage files vs let HM do it"

## Future Considerations

### Potential Improvements

1. **Configuration option**: Allow users to disable auto-symlink via environment variable
2. **Better messaging**: Inform users when HM is detected and symlink creation is skipped
3. **Documentation updates**: Ensure both approaches are clearly documented in README

### Alternative Approaches Considered

**Option 1**: Always auto-create (original implementation)
- Pro: Simple, works for everyone
- Con: Conflicts with Home Manager philosophy

**Option 2**: Never auto-create (claude-code-nix approach)
- Pro: No conflicts, follows HM philosophy
- Con: Poor experience for non-HM users

**Option 3**: Smart detection (chosen approach)
- Pro: Best of both worlds, respects user choice
- Con: Slightly more complex, requires maintenance

## Conclusion

The symlink and Home Manager integration provides:

1. **Seamless macOS permission persistence** for all users
2. **Respect for Home Manager's declarative philosophy** when present
3. **Convenience for newcomers** to the Nix ecosystem
4. **Clear documentation** for both approaches
5. **Community-standard detection methods** for reliability

This solution prioritizes user experience while maintaining compatibility with established Nix ecosystem patterns and philosophies.
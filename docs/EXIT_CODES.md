# Exit Code Registry

This document catalogs all exit codes used across the project for debugging and maintenance.

## Exit Code Ranges

| Range | Category | Usage |
|-------|----------|-------|
| `0` | Success | Normal script completion |
| `1-9` | **RESERVED** | Do not use - reserved for shell/system errors |
| `10-19` | Dependencies | Missing packages, library issues, prerequisite failures |
| `20-29` | Configuration | Config file errors, settings problems, validation failures |
| `30-39` | Build/Compile | Meson, ninja, compilation errors |
| `40-49` | Installation | File copy, permission, installation failures |
| `50-59` | Verification | Binary checks, validation, post-install verification |
| `60-69` | User Interaction | User input errors, permission denied, sudo issues |
| `70-79` | File System | Directory creation, file operations, disk space |
| `80-89` | Network | Git clone, downloads, connectivity issues |
| `90-99` | Reserved | Future use |

---

## Allocated Exit Codes

### 00_preflight.sh

| Code | Constant | Description |
|------|----------|-------------|
| 60 | `EXIT_NOT_ROOT` | Script must be run as root |
| 61 | `EXIT_WRONG_DISTRO` | Not running on Debian Trixie |
| 80 | `EXIT_NO_INTERNET` | No internet connectivity detected |

### 01_base_deps.sh

| Code | Constant | Description |
|------|----------|-------------|
| 10 | `EXIT_BASE_PACKAGE_FAILED` | Failed to install base package |

### 02_video_input.sh

| Code | Constant | Description |
|------|----------|-------------|
| 11 | `EXIT_VIDEO_PACKAGE_FAILED` | Failed to install video/input package |

### 03_wayland_core.sh

| Code | Constant | Description |
|------|----------|-------------|
| 12 | `EXIT_WAYLAND_PACKAGE_FAILED` | Failed to install Wayland package |
| 41 | `EXIT_BRAVE_INSTALL_FAILED` | Brave browser installation failed |

### 03z_panel_choice.sh

| Code | Constant | Description |
|------|----------|-------------|
| 62 | `EXIT_INVALID_PANEL_CHOICE` | User selected invalid panel option |

### 04a_waybar_install.sh

| Code | Constant | Description |
|------|----------|-------------|
| 13 | `EXIT_WAYBAR_PACKAGE_FAILED` | Failed to install Waybar package |

### 04b_sfwbar_build.sh

| Code | Constant | Description |
|------|----------|-------------|
| 10 | `EXIT_DEPENDENCY_MISSING` | gtk-layer-shell library not available |
| 11 | `EXIT_USER_DETECTION_FAILED` | Cannot determine non-root user |
| 12 | `EXIT_GIT_CLONE_FAILED` | Failed to clone sfwbar repository |
| 13 | `EXIT_MESON_CONFIG_FAILED` | Meson configuration failed |
| 14 | `EXIT_NINJA_BUILD_FAILED` | Ninja compilation failed |
| 15 | `EXIT_NINJA_INSTALL_FAILED` | Ninja installation failed |
| 16 | `EXIT_BINARY_VERIFICATION_FAILED` | Binary not found after install |

### 05_user_config.sh

| Code | Constant | Description |
|------|----------|-------------|
| 71 | `EXIT_CONFIG_DIR_FAILED` | Failed to create config directory |
| 72 | `EXIT_CONFIG_SYMLINK_FAILED` | Failed to create config symlink |

---

## Adding New Exit Codes

### Process

1. **Choose appropriate range** based on error category
2. **Check this registry** to avoid conflicts
3. **Define readonly constant** at top of script:
   ```bash
   readonly EXIT_YOUR_ERROR=XX
   ```
4. **Use the constant** when exiting:
   ```bash
   log_error "Clear description"
   export SCRIPT_SELF_REPORTED_ERROR=1
   exit $EXIT_YOUR_ERROR
   ```
5. **Update this registry** with code, constant, and description
6. **Update main.sh** case statement with human-readable reason
7. **Commit both changes together**

### Example

```bash
#!/bin/bash
# steps/06_new_step.sh

set -euo pipefail

# Exit codes
readonly EXIT_CUSTOM_ERROR=42

# ... later in script ...

if ! some_command; then
    log_error "some_command failed: detailed reason"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_CUSTOM_ERROR
fi
```

Then update `main.sh`:
```bash
case $exit_code in
    # ... existing cases ...
    42) log_error "Reason: Custom error description" ;;
esac
```

---

## Quick Reference for Debugging

When you see an exit code in the logs, use this table to quickly identify the source:

| Code | Quick Lookup |
|------|--------------|
| 10 | Dependency missing (sfwbar) or base package (01) |
| 11 | User detection (04b) or video package (02) |
| 12 | Git clone (04b) or Wayland package (03) |
| 13 | Meson config (04b) or Waybar package (04a) |
| 14 | Ninja build (04b) |
| 15 | Ninja install (04b) |
| 16 | Binary verification (04b) |
| 41 | Brave install (03) |
| 60 | Not root (00) |
| 61 | Wrong distro (00) |
| 62 | Invalid panel choice (04) |
| 71 | Config dir creation (05) |
| 72 | Config symlink (05) |
| 80 | No internet (00) |

---

## Reserved Codes (Do Not Use)

- `1`: Generic error - **NEVER USE** (use specific codes)
- `2`: Misuse of shell builtins (Bash reserved)
- `126`: Command found but not executable (Bash reserved)
- `127`: Command not found (Bash reserved)
- `128+N`: Fatal signal N (Bash reserved)
- `130`: Script terminated by Ctrl+C (Bash reserved)
- `255`: Exit status out of range (Bash reserved)

---

## Enforcement

The pre-commit hook at `.git/hooks/pre-commit` validates:
- No `exit 1` in any .sh files (specific codes required)
- Exit codes are within documented ranges
- Exit codes have corresponding constants defined

To bypass (not recommended):
```bash
git commit --no-verify
```

---

## See Also

- `docs/ERROR_HANDLING.md` - Error handling patterns and best practices
- `main.sh` - Main orchestrator with exit code case statement
- `lib/utils.sh` - Error handler implementation

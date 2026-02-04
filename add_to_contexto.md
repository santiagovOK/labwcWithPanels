# Context Notes for Agents

## Critical Solutions Implemented

### 1. Interactive Prompts with sudo (stdin preservation)

**Problem:** When scripts run with `sudo`, stdin is lost and interactive prompts fail.

**Implemented solution:**

#### In `install.sh`:
```bash
# Detect interactive mode and redirect from /dev/tty
if [ -t 0 ]; then
    sudo -E bash -c './main.sh < /dev/tty'
else
    sudo -E ./main.sh
fi
```

#### In `main.sh`:
```bash
# When executing child scripts, preserve stdin
for script in "${SCRIPT_FILES[@]}"; do
    if [ -t 0 ]; then
        ./"$script" < /dev/tty
    else
        ./"$script"
    fi
done
```

#### In `lib/utils.sh` (`safe_prompt` function):
```bash
safe_prompt() {
    local prompt_text="$1"
    local default_value="${2:-N}"
    local response=""
    
    # Read directly from /dev/tty (NOT from stdin)
    if [ -e /dev/tty ]; then
        read -r -p "$prompt_text " response < /dev/tty
        echo "$response"
    else
        log_warn "Non-interactive mode detected. Using default: $default_value"
        echo "$default_value"
    fi
}
```

**Key lessons:**
- DO NOT use `[ -t 0 ]` in subshells (`response=$(...)`) — always fails
- Use `[ -e /dev/tty ]` to detect available terminal
- Read directly with `< /dev/tty` instead of relying on stdin
- Pass stdin explicitly with `< /dev/tty` when running with `sudo`

**Use cases:**
- Installers with `curl | bash` (non-interactive)
- Installers executed manually with `sudo` (interactive)
- Scripts that need prompts inside subshells

---

### 2. Package Installation Detection (dpkg checks)

**Problem:** `dpkg -l "$pkg" &> /dev/null` gives false positives — returns success even for uninstalled packages (it just means dpkg knows the package name exists).

**Implemented solution:**

#### Wrong approach (DO NOT USE):
```bash
# ❌ INCORRECT - gives false positives
if dpkg -l "$pkg" &> /dev/null; then
    echo "$pkg is already installed."
    return 0
fi
```

#### Correct approach (USE THIS):
```bash
# ✅ CORRECT - checks exact install status
is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Usage in safe_install or similar
if is_installed "$pkg"; then
    log_success "$pkg is already installed."
    return 0
fi
```

**Key lessons:**
- `dpkg -l` returns 0 if package is known (not necessarily installed)
- `dpkg-query -W -f='${Status}'` returns exact status: `install ok installed`
- Always check for exact string `"install ok installed"` to avoid false positives
- Package states: `rc` (removed config), `ii` (installed), `un` (unknown), etc.

**Impact:**
- Prevents skipping package installations
- Ensures packages are truly installed before marking as complete
- Critical for package managers and installation scripts

---

## Branch Strategy

### Established branches:
- `main` - Stable production
- `testing` - Testing installer via curl
- `develop` - Feature integration (future)
- `feature/*` - Individual development

### Workflow:
1. Changes in `main` are merged to `testing` for validation
2. Testing branch allows testing remote installation
3. PRs required for critical changes


- Note: Do NOT commit files that are listed in `.gitignore`.
  - Files intentionally ignored (build artifacts, local configs, secrets, logs)
    should not be tracked or included in commits.
  - If you see local changes for ignored files, add them to `.gitignore`
    or keep them as local-only edits; they do not require commits.
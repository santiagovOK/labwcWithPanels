# Error Handling Best Practices

This document captures the error handling patterns and lessons learned during the development of the Labwc installer.

## Table of Contents

- [The Problem: Bash Traps and set -e Interaction](#the-problem-bash-traps-and-set--e-interaction)
- [Solution Patterns](#solution-patterns)
- [Mandatory Standards](#mandatory-standards)
- [Common Anti-Patterns to Avoid](#common-anti-patterns-to-avoid)

---

## The Problem: Bash Traps and set -e Interaction

### Background

This project uses strict error handling:
```bash
set -euo pipefail
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM
```

This combination creates challenges when trying to capture exit codes from failed commands or subscripts.

### Issue 1: `|| { local exit_code=$? }` Pattern Fails

**The Broken Pattern:**
```bash
./"$script" || {
    local exit_code=$?  # ← TRAP FIRES HERE!
    log_error "Script failed"
    exit "$exit_code"
}
```

**Why It Fails:**
1. The `local` builtin returns the exit status of the command substitution (`$?`)
2. With `set -e` active, the non-zero exit from `local exit_code=<non-zero>` triggers the ERR trap
3. The trap captures `BASH_COMMAND="local exit_code=$"` (truncated during parameter expansion)
4. Result: `Failed command: local exit_code=$`

### Issue 2: set +e Doesn't Disable the Trap

**Incorrect Assumption:**
```bash
set +e  # This only disables auto-exit, NOT the trap!
./"$script"
exit_code=$?
set -e
```

**Problem:**
- `set +e` disables automatic exit on non-zero status
- The **ERR trap still fires** when commands fail
- The trap executes before you can capture the exit code

---

## Solution Patterns

### Pattern 1: Disable ERR Trap Temporarily (Main Orchestrator)

**Use Case:** Main script executing subscripts that need exit code capture

**Implementation:**
```bash
# Temporarily disable ERR trap and errexit
trap - ERR
set +e
run_step_script "$script"
exit_code=$?
set -e
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR
```

**Why This Works:**
- `trap - ERR` removes the trap handler entirely
- Commands can fail without triggering error_handler
- Exit code is safely captured
- Trap is re-enabled after capture completes

### Pattern 2: Function Wrapper for Script Execution

**The `run_step_script()` Function:**
```bash
run_step_script() {
    local script="$1"
    
    # Execute with stdin redirection if available
    # Note: Caller manages trap and set -e state
    if [ -t 0 ]; then
        ./"$script" < /dev/tty
    else
        ./"$script"
    fi
}
```

**Usage:**
```bash
trap - ERR
set +e
run_step_script "$script"
exit_code=$?
set -e
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR
```

### Pattern 3: Quiet-Exit Flag for Subscripts

**Use Case:** Prevent duplicate error messages when subscripts handle their own errors

**Implementation in Subscript:**
```bash
if some_command fails; then
    log_error "Detailed error message about what failed"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_SPECIFIC_CODE
fi
```

**Implementation in error_handler():**
```bash
error_handler() {
    # ... validation ...
    
    # Check if the script already reported the error
    if [[ "${SCRIPT_SELF_REPORTED_ERROR:-0}" == "1" ]]; then
        # Script already logged the error, exit silently
        exit "$exit_code"
    fi
    
    # Otherwise, log the error
    log_error "Critical failure detected!"
    # ...
}
```

### Pattern 4: Safe Install with set +e (From safe_install)

**The Proven Pattern:**
```bash
set +e
apt-get install -y -q "$pkg"
local exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    # Handle error
fi
```

**Why This Works:**
- Temporarily disables `set -e` for the entire block
- Assignment happens with error exit disabled
- Re-enable before conditional check

---

## Mandatory Standards

### 1. Specific Exit Codes Only

**REQUIRED:** All scripts must use specific exit codes, never generic `exit 1`

**Exit Code Ranges:**
- `10-19`: Dependency and prerequisite errors
- `20-29`: Configuration errors
- `30-39`: Build and compilation errors
- `40-49`: Installation errors
- `50-59`: Verification and validation errors
- `60-69`: User interaction errors
- `70-79`: File system errors
- `80-89`: Network errors
- `90-99`: Reserved for future use

**Template:**
```bash
#!/bin/bash
# script_name.sh

set -euo pipefail

# Exit codes for specific failures
readonly EXIT_DEPENDENCY_MISSING=10
readonly EXIT_CONFIG_FAILED=20
readonly EXIT_BUILD_FAILED=30
# ... add all codes used in this script

# ... rest of script ...

if some_condition; then
    log_error "Specific error message"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_DEPENDENCY_MISSING
fi
```

### 2. Always Set SCRIPT_SELF_REPORTED_ERROR

Before any `exit` with error code:
```bash
log_error "Clear description of what failed"
export SCRIPT_SELF_REPORTED_ERROR=1
exit $EXIT_CODE
```

### 3. Document New Exit Codes

All exit codes must be:
1. Defined as readonly constants at script start
2. Documented in `docs/EXIT_CODES.md`
3. Added to the case statement in `main.sh`

---

## Common Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Generic Exit Code
```bash
if [ $? -ne 0 ]; then
    log_error "Something failed"
    exit 1  # BAD: No context
fi
```

### ✅ Correct Pattern
```bash
if ! some_command; then
    log_error "some_command failed: specific reason"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_COMMAND_FAILED
fi
```

### ❌ Anti-Pattern 2: Using `local` in Error Blocks
```bash
command || {
    local exit_code=$?  # BAD: Triggers trap
    exit "$exit_code"
}
```

### ✅ Correct Pattern
```bash
set +e
command
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    exit $EXIT_CODE
fi
```

### ❌ Anti-Pattern 3: Not Disabling Trap When Needed
```bash
set +e  # Only disables auto-exit
./"$script"  # Trap still fires!
exit_code=$?
```

### ✅ Correct Pattern
```bash
trap - ERR
set +e
./"$script"
exit_code=$?
set -e
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR
```

---

## Reference

- See `docs/EXIT_CODES.md` for complete exit code registry
- See `lib/utils.sh` for `error_handler()` implementation
- See `main.sh` for `run_step_script()` implementation
- See `steps/04b_sfwbar_build.sh` for reference implementation

---

## Testing Error Handling

To verify error handling works correctly:

1. **Test specific exit codes:**
   ```bash
   # Temporarily add to a script:
   exit $EXIT_TEST_CODE
   # Verify main.sh displays correct reason
   ```

2. **Test trap disabling:**
   ```bash
   # Add debug output to error_handler
   # Verify it doesn't fire during script execution
   ```

3. **Test quiet-exit:**
   ```bash
   # Verify no duplicate error messages in output
   ```

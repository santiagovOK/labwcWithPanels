# Debian 13 (Trixie) Minimal Setup: Labwc + Panels

This is a Bash orchestration script to automate the installation of a minimal Wayland environment using **Labwc** (Compositor) with configurable panel options on Debian 13.

## Panel Options

| Panel | Status | Description |
| :--- | :--- | :--- |
| **Waybar** | ✅ **Working** | Highly customizable Wayland bar (default) |
| **sfwbar** | ✅ **Working** | Simple Wayland bar with taskbar support |
| **xfce4-panel** | 🔄 **Pending** | Full-featured panel from XFCE desktop |

---

## Quick Start

### 1. Recommended Installation (via curl)

Run the following command to download and start the setup automatically:

```bash
curl -sL https://raw.githubusercontent.com/santiagovOK/labwcWithPanels/main/install.sh | bash
```

**Testing Branch (for development/testing):**

```bash
curl -fsSL https://raw.githubusercontent.com/santiagovOK/labwcWithPanels/testing/install.sh | BRANCH=testing bash
```

### 2. Manual Installation

If you prefer to clone the repository manually:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/santiagovOK/labwcWithPanels.git
    cd labwcWithPanels
    ```

2.  **Run the Orchestrator:**
    ```bash
    chmod +x main.sh
    sudo ./main.sh
    ```

### Prerequisites

* **OS:** Debian 13 "Trixie" (Testing/Testing-based)
* **User:** A user with `sudo` privileges.
* **Internet:** Active connection required.

---

## ⚠️ Post-Installation Configuration

After running the installer, **configuration files** are deployed to `~/.config/` via symlinks. These configurations may need manual review and adjustment:

### Critical Files to Review

**Labwc Configuration:**
- **`~/.config/labwc/autostart`** - Auto-start applications (panel, terminal, etc.)
- **`~/.config/labwc/rc.xml`** - Keybindings, window rules, compositor settings
- **`~/.config/labwc/environment`** - Environment variables
- **`~/.config/labwc/menu.xml`** - Right-click menu items

**Panel Configuration (depending on your choice):**
- **Waybar**: `~/.config/waybar/config` and `~/.config/waybar/style.css`
- **sfwbar**: `~/.config/sfwbar/sfwbar.config` and `~/.config/sfwbar/sfwbar.css`

### Common Issues

1. **Panel not starting:** Check `~/.config/labwc/autostart` for correct panel command
2. **Wrong monitor/display:** Adjust output settings in `~/.config/labwc/rc.xml`
3. **Keybindings not working:** Review bindings in `~/.config/labwc/rc.xml`
4. **Panel appearance:** Modify CSS files in respective panel config directories
5. **Display Manager/Greeter:** This installer does NOT include a display manager (LightDM, GDM, SDDM, etc.). You may need to configure one separately or start labwc manually from TTY.

**Tip:** Configuration files are **symlinked** from this repository. You can either:
- Edit symlinked files directly (changes tracked in git)
- Break symlinks and copy files to customize independently

-----

## 📂 Project Structure

| Directory | Description |
| :--- | :--- |
| **`main.sh`** | The entry point. Initializes logging and runs steps in order. |
| **`lib/`** | Contains `utils.sh` (logging colors, error traps, validation functions). |
| **`steps/`** | Numbered scripts containing the actual logic. |
| **`config/`** | Source dotfiles for Labwc and panel configurations (symlinked during install). |
| **`logs/`** | Auto-generated logs for every installation attempt. |
| **`img/`** | Image source files. |
| **`docs/`** | Documentation assets and architecture source files. |
-----

## 🛡 Features

  * **Panel Choice:** Choose between different panel options (Waybar currently supported, sfwbar and xfce4-panel pending).
  * **Atomic Execution:** The script stops immediately if any step fails (`set -e`).
  * **Validation First:** Checks for internet connectivity, root privileges, and OS version before making changes.
  * **Detailed Logging:** Every action is logged to `logs/install_YYYY-MM-DD.log`.
  * **Idempotent-ish:** Checks if packages are already installed to speed up re-runs.


## 🏗 Architecture (not updated right now)

The installation process is driven by a central orchestrator (`install.sh`) that executes isolated, numbered steps. The system relies on a global error trap and strict validation logic.

![img/architecture.mmd](img/.png)

## 🌿 Branch Strategy

This project uses a structured branching model for stable releases and testing:

| Branch | Purpose | Installation |
| :--- | :--- | :--- |
| **`main`** | Production-ready stable releases | `curl -sL https://.../main/install.sh \| bash` |
| **`develop`** | Integration branch for new features | Manual clone and checkout |
| **`testing`** | Testing installer and new changes via curl | `curl -fsSL https://.../testing/install.sh \| BRANCH=testing bash` |
| **`feature/*`** | Individual feature development | Manual clone and checkout |

### Workflow Rules

1. **Direct commits** only to `feature/*` branches
2. **Pull Requests** required for merging into `testing`, `develop`, or `main`
3. **Testing first**: Changes should be validated in `testing` before merging to `develop`
4. **Code review**: At least 1 approval required for PRs to `develop` or `main`

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE.txt) file for details.

# Debian 13 (Trixie) Minimal Setup: Labwc + Waybar

This is a Bash orchestration script to automate the installation of a minimal Wayland environment using **Labwc** (Compositor) and **Waybar** (Status Bar) on Debian 13.

---

## Quick Start

### 1. Recommended Installation (via curl)

Run the following command to download and start the setup automatically:

```bash
curl -sL https://raw.githubusercontent.com/santiagovOK/labwc_waybar_setup/main/install.sh | bash
```

### 2. Manual Installation

If you prefer to clone the repository manually:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/santiagovOK/labwc_waybar_setup.git
    cd labwc_waybar_setup
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

-----

## 📂 Project Structure

| Directory | Description |
| :--- | :--- |
| **`main.sh`** | The entry point. Initializes logging and runs steps in order. |
| **`lib/`** | Contains `utils.sh` (logging colors, error traps, validation functions). |
| **`steps/`** | Numbered scripts containing the actual logic. |
| **`config/`** | Source dotfiles for Labwc and Waybar (symlinked during install). |
| **`logs/`** | Auto-generated logs for every installation attempt. |
| **`img/`** | Image source files. |
| **`docs/`** | Documentation assets and architecture source files. |
-----

## 🛡 Features

  * **Atomic Execution:** The script stops immediately if any step fails (`set -e`).
  * **Validation First:** Checks for internet connectivity, root privileges, and OS version before making changes.
  * **Detailed Logging:** Every action is logged to `logs/install_YYYY-MM-DD.log`.
  * **Idempotent-ish:** Checks if packages are already installed to speed up re-runs.


## 🏗 Architecture

The installation process is driven by a central orchestrator (`install.sh`) that executes isolated, numbered steps. The system relies on a global error trap and strict validation logic.

![img/architecture.mmd](img/architecture.png)

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE.txt) file for details.

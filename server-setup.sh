#!/bin/bash

#==============================================================================
# Streamlined System Initialization and Configuration Script
#
# Author:        Craig Wilson
# Version:       0.1
# Last Modified: 2025-06-20
#
# Description:
# This script automates the initial setup of a Debian-based server by:
#   - Installing a consolidated list of essential tools and utilities.
#   - Configuring system settings for performance and security.
#   - Customizing the login experience with a legal banner and system info.
#
# Tested on:
#   - Ubuntu 24.04 (Lunar Lobster)
#
#==============================================================================


# --- Script Configuration and Preamble ---

# Exit immediately if a command exits with a non-zero status.
set -e

# Set DEBIAN_FRONTEND to noninteractive to prevent prompts.
export DEBIAN_FRONTEND=noninteractive

# --- Function Definitions ---

#
# Performs initial checks to ensure script can run successfully.
#
initial_checks() {
  echo "▶ Performing initial checks..."
  # Check for root privileges
  if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this script as root or using sudo." >&2
    exit 1
  fi
}

#
# Updates package lists and installs all required packages in one go.
#
install_packages() {
  echo "▶ Updating package repositories..."

  # Add the PPA for fastfetch
  echo "▶ Adding PPA for fastfetch..."
  add-apt-repository -y ppa:zhangsongcui3371/fastfetch 2>&1 | grep -v "WARNING: apt does not have a stable CLI interface"

  echo "▶ Updating package lists..."
  apt-get update -y 2>&1 | grep -v "WARNING: apt does not have a stable CLI interface"

  echo "▶ Installing all required packages..."
  apt-get install -y \
    btop \
    cmatrix \
    curl \
    wget \
    vim \
    nano \
    unzip \
    net-tools \
    build-essential \
    speedtest-cli \
    python3 \
    python3-pip \
    python3-venv \
    git \
    openvpn \
    linux-tools-common \
    smartmontools \
    nvme-cli \
    "linux-tools-$(uname -r)" \
    cpufrequtils \
    fastfetch \
    2>&1 | grep -v "WARNING: apt does not have a stable CLI interface"
  echo "✔ Package installation complete."
}

#
# Configures the CPU governor for maximum performance.
#
configure_cpu_governor() {
  echo "▶ Configuring CPU governor to 'performance'..."
  # Set the governor in the configuration file
  echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
  echo "✔ CPU governor configured."
}

#
# Sets a legal disclaimer banner for SSH sessions.
#
configure_ssh() {
  echo "▶ Configuring SSH banner..."
  local banner_file="/etc/ssh/banner"
  local ssh_config="/etc/ssh/sshd_config"

  # Create the SSH banner file
  cat << EOF > "$banner_file"
*******************************************************************************
** NOTICE TO USERS OF THIS SYSTEM                                            **
** **
** This computer system is for authorized use only.                          **
** **
** By using this system, the user consents to such interception, monitoring, **
** recording, copying, auditing, inspection, and disclosure at the           **
** discretion of authorized site or personnel.                               **
** **
** By continuing to use this system, you indicate your awareness of and      **
** consent to these terms and conditions of use.                             **
*******************************************************************************
EOF
  # Add the banner configuration to sshd_config if it doesn't exist
  if ! grep -q "^Banner $banner_file" "$ssh_config"; then
    echo "Banner $banner_file" >> "$ssh_config"
  fi
  echo "✔ SSH banner configured."
}

#
# Configures fastfetch to display on login and disables default MOTD.
#
configure_motd() {
  echo "▶ Configuring fastfetch as the login banner..."
  # Create a script to run fastfetch on login for all users
  cat << EOF > /etc/profile.d/00-fastfetch.sh
#!/bin/bash
# Display system information using fastfetch
fastfetch
EOF

  chmod +x /etc/profile.d/00-fastfetch.sh

  # Disable default MOTD files by renaming them with a .disabled extension
  echo "▶ Disabling default MOTD..."
  for file in /etc/update-motd.d/*; do
    # Check if it's a file and not already disabled
    if [[ -f "$file" && ! "$file" == *.disabled ]]; then
      mv "$file" "$file.disabled" 2>/dev/null || true
    fi
  done
  echo "✔ MOTD configured to show fastfetch."
}

#
# Hardens OpenSSL configuration to modern standards.
#
configure_openssl() {
  echo "▶ Configuring OpenSSL security settings..."
  local openssl_config="/etc/ssl/openssl.cnf"

  # Backup the original configuration file
  cp "$openssl_config" "$openssl_config.bak"

  # Add MinProtocol and CipherString if they don't already exist
  if ! grep -q "^MinProtocol" "$openssl_config"; then
    sed -i '/^\[system_default_sect\]$/a MinProtocol = TLSv1.2' "$openssl_config"
  fi
  if ! grep -q "^CipherString" "$openssl_config"; then
    sed -i '/^\[system_default_sect\]$/a CipherString = DEFAULT@SECLEVEL=2' "$openssl_config"
  fi
  echo "✔ OpenSSL security settings applied."
}

#
# Enables and restarts all necessary services.
#
restart_services() {
  echo "▶ Enabling and restarting services..."

  # Enable and start cpufrequtils
  systemctl enable cpufrequtils
  systemctl start cpufrequtils

  # Restart services that use SSH or OpenSSL
  local services_to_restart=("ssh" "apache2" "nginx")
  for service in "${services_to_restart[@]}"; do
    if systemctl list-units --full --all | grep -q "${service}.service"; then
      echo "  - Restarting ${service}..."
      systemctl restart "${service}"
    else
      echo "  - Service ${service} not found, skipping restart."
    fi
  done
  echo "✔ Services have been restarted."
}

#
# Configure the system timezone to Melbourne, Australia.
#
configure_timezone() {
    echo "▶ Configuring system timezone to Melbourne, Australia..."
    # Set the timezone to Melbourne
    sudo timedatectl set-timezone Norway/Oslo
    echo "✔ Timezone configured to Melbourne, Australia."
}

#
# Clears on-disk history for all users and the root account.
#
clean_history() {
    echo "▶ Clearing on-disk command history files..."

    # Unset HISTFILE for the script's session to prevent its own commands from being logged.
    unset HISTFILE

    # Define the common history filenames to clear.
    local history_files=(".bash_history" ".zsh_history" ".fish_history")

    # Clear history for the root user.
    echo "  - Clearing history for root user..."
    for hist_file in "${history_files[@]}"; do
        # Check if the history file exists for root before trying to clear it.
        if [ -f "/root/${hist_file}" ]; then
            cat /dev/null > "/root/${hist_file}"
        fi
    done

    # Iterate over user directories in /home.
    for user_dir in /home/*; do
        # Ensure it is a directory.
        if [ -d "$user_dir" ]; then
            local user
            user=$(basename "$user_dir")
            echo "  - Clearing history for user: $user"
            for hist_file in "${history_files[@]}"; do
                local full_path="${user_dir}/${hist_file}"
                # Check if the history file exists before trying to clear it.
                if [ -f "$full_path" ]; then
                    cat /dev/null > "$full_path"
                fi
            done
        fi
    done

    echo "✔ On-disk history files cleared."
    echo "ℹ NOTE: To clear the history of your CURRENT terminal session, please run 'history -c' after this script completes."
}

# --- Main Execution ---

main() {
  initial_checks
  install_packages
  configure_cpu_governor
  configure_ssh
  configure_motd
  configure_openssl
  configure_timezone
  restart_services
  clean_history

  echo -e "\n✔  System setup and configuration are complete."
}

main "$@"
# --- End of Script ---

#!/usr/bin/env bash

# Function to install necessary dependencies
function install_dependencies {
    echo "Installing necessary dependencies..."
    apt-get update
    apt-get install -y curl sudo
}

# Function to create LXC container with TurnKey Core Debian 12 and install SteamCMD
function create_container_with_turnkey_core_and_steamcmd {
    # Function to display input dialog and capture user input
    function get_input {
        local title="$1"
        local prompt="$2"
        local default="$3"
        local result

        result=$(whiptail --inputbox "$prompt" 8 78 "$default" --title "$title" 3>&1 1>&2 2>&3)
        exit_status=$?
        echo "$result"
        return $exit_status
    }

    # Install necessary dependencies
    install_dependencies

    # Get user input for container ID
    CT_ID=$(get_input "Container ID" "Enter the container ID:" "100")
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Get user input for hostname
    HOSTNAME=$(get_input "Hostname" "Enter the hostname:" "turnkey-core")
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Get user input for storage
    STORAGE=$(get_input "Storage" "Enter the storage:" "local-lvm")
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Get user input for password
    PASSWORD=$(whiptail --passwordbox "Enter the root password:" 8 78 --title "Password" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Check if the container with the same ID exists, if yes, delete it
    if pct list | grep -q "^$CT_ID "; then
        pct destroy $CT_ID
    fi

    # Download TurnKey Core Debian 12 template if not already available
    pveam available | grep "turnkey-core-debian-12-default" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Downloading TurnKey Core Debian 12 template..."
        pveam download local turnkey-core-debian-12-default
    else
        echo "TurnKey Core Debian 12 template is already available."
    fi

    # Create LXC container using the downloaded template
    echo "Creating LXC container with TurnKey Core Debian 12..."
    pct create $CT_ID turnkey-core-debian-12-default --hostname $HOSTNAME --storage $STORAGE --password $PASSWORD

    # Start the container
    echo "Starting the container..."
    pct start $CT_ID

    # Install SteamCMD inside the container
    echo "Installing SteamCMD..."
    pct exec $CT_ID -- apt-get update
    pct exec $CT_ID -- apt-get install -y steamcmd

    echo "SteamCMD installed successfully."
}

# Call the function to create LXC container with TurnKey Core Debian 12 and install SteamCMD
create_container_with_turnkey_core_and_steamcmd

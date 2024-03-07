#!/bin/bash

# Function to display animated loading
function show_loading {
    local i sp n
    sp='/-\|'
    n=${#sp}
    printf ' '
    while true; do
        printf '%s' "${sp:i++%n:1}"
        sleep 0.1
        printf '\b'
    done
}

# Function to stop animated loading
function stop_loading {
    kill "$1" 2>/dev/null
    printf '\b \n'
}

# Function to install necessary dependencies
function install_dependencies {
    echo "Installing necessary dependencies..."
    show_loading &
    local loading_pid=$!
    apt-get update &>/dev/null
    apt-get install -y curl sudo &>/dev/null
    stop_loading $loading_pid
    echo "Dependencies installed successfully."
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

    # Function to display yes/no dialog and capture user choice
    function get_yesno {
        local title="$1"
        local prompt="$2"
        local default="$3"
        local result

        result=$(whiptail --yesno "$prompt" 8 78 --title "$title" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [ $exit_status -eq 0 ]; then
            echo "yes"
        else
            echo "no"
        fi
    }

    # Install necessary dependencies
    install_dependencies

    # Get user input for container ID
    CT_ID=$(get_input "Container ID" "Enter the container ID:" "100")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "Container ID: $CT_ID"

    # Get user input for hostname
    HOSTNAME=$(get_input "Hostname" "Enter the hostname:" "turnkey-core")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "Hostname: $HOSTNAME"

    # Get user input for storage
    STORAGE=$(get_input "Storage" "Enter the storage:" "local-lvm")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "Storage: $STORAGE"

    # Get user input for password
    PASSWORD=$(whiptail --passwordbox "Enter the root password:" 8 78 --title "Password" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "Root Password: ********"

    # Get user input for CPU cores
    CORE_COUNT=$(get_input "CPU Cores" "Enter the number of CPU cores:" "2")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "CPU Cores: $CORE_COUNT"

    # Get user input for RAM size
    RAM_SIZE=$(get_input "RAM Size" "Enter the RAM size in MB:" "2048")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "RAM Size: $RAM_SIZE MB"

    # Ask user if DHCP should be used for network configuration
    DHCP=$(get_yesno "Network Configuration" "Use DHCP for network configuration?" "yes")
    if [ "$DHCP" == "yes" ]; then
        echo "Using DHCP for network configuration."
    else
        # Get user input for IP address if DHCP is not selected
        IP_ADDRESS=$(get_input "IP Address" "Enter the IP address:" "")
        if [ $? -ne 0 ]; then
            exit 1
        fi
        echo "IP Address: $IP_ADDRESS"
    fi

    # Check if the container with the same ID exists, if yes, delete it
    if pct list | grep -q "^$CT_ID "; then
        pct destroy $CT_ID
        echo "Existing container with ID $CT_ID found and destroyed."
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
    show_loading &
    local loading_pid=$!
    if [ "$DHCP" == "yes" ]; then
        pct create $CT_ID turnkey-core-debian-12-default --hostname $HOSTNAME --storage $STORAGE --password $PASSWORD --cores $CORE_COUNT --memory $RAM_SIZE --net0 name=eth0,bridge=vmbr0,ip=dhcp &>/dev/null
    else
        pct create $CT_ID turnkey-core-debian-12-default --hostname $HOSTNAME --storage $STORAGE --password $PASSWORD --cores $CORE_COUNT --memory $RAM_SIZE --net0 name=eth0,bridge=vmbr0,ip=$IP_ADDRESS &>/dev/null
    fi
    stop_loading $loading_pid
    echo "LXC container created successfully."

    # Start the container
    echo "Starting the container..."
    show_loading &
    loading_pid=$!
    pct start $CT_ID &>/dev/null
    stop_loading $loading_pid
    echo "Container started successfully."

    # Install SteamCMD inside the container
    echo "Installing SteamCMD..."
    show_loading &
    loading_pid=$!
    pct exec $CT_ID -- apt-get update &>/dev/null
    pct exec $CT_ID -- apt-get install -y steamcmd &>/dev/null
    stop_loading $loading_pid
    echo "SteamCMD installed successfully."

    echo "All steps completed successfully."
}

# Call the function to create LXC container with TurnKey Core Debian 12 and install SteamCMD
create_container_with_turnkey_core_and_steamcmd

#!/usr/bin/env bash

# Function to install necessary dependencies
function install_dependencies {
    echo "Installing necessary dependencies..."
    apt-get update
    apt-get install -y curl sudo whiptail
}

# Function to create LXC container with custom template and install dependencies
function create_container_with_custom_template_and_dependencies {
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
    STORAGE_OPTIONS=("local-lvm" "local" "zfs" "ceph")
    STORAGE=$(whiptail --menu "Select storage:" 15 78 4 "${STORAGE_OPTIONS[@]}" 3>&1 1>&2 2>&3)
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

    # Update and upgrade the system
    echo "Updating system..."
    apt-get update &>/dev/null
    apt-get -y upgrade &>/dev/null
    echo "System updated."

    # Select LXC template
    LXC_TEMPLATE=$(pct list templates | whiptail --menu "Select LXC template:" 15 78 4 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "LXC Template: $LXC_TEMPLATE"

    # Create LXC container using the selected template
    echo "Creating LXC container..."
    pct create $CT_ID "$LXC_TEMPLATE" --hostname $HOSTNAME --storage $STORAGE --password $PASSWORD --cores $CORE_COUNT --memory $RAM_SIZE --net0 $NET --ipconfig0 $IP_ADDRESS
    echo "LXC container created."

    # Start the container
    echo "Starting LXC container..."
    pct start $CT_ID
    echo "LXC container started."

    # Output summary
    echo "-------------------------"
    echo "Container ID: $CT_ID"
    echo "Hostname: $HOSTNAME"
    echo "Storage: $STORAGE"
    echo "Root Password: $PASSWORD"
    echo "CPU Cores: $CORE_COUNT"
    echo "RAM Size: $RAM_SIZE MB"
}

# Run the function to create container
create_container_with_custom_template_and_dependencies

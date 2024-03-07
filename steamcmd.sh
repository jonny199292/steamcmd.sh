#!/bin/bash

# Function to install necessary dependencies
function install_dependencies {
    echo "Installing necessary dependencies..."
    apt-get update
    apt-get install -y curl sudo
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

    # Create LXC container using the custom template
    echo "Creating LXC container with custom template..."
    pct create $CT_ID <path_to_your_custom_template>/debian-12-turnkey-core_18.0-1_amd64.tar.gz --hostname $HOSTNAME --storage $STORAGE --password $PASSWORD --cores $CORE_COUNT --memory $RAM_SIZE --net0 name=eth0,bridge=vmbr0,ip=$IP_ADDRESS
    echo "LXC container created successfully."

    # Start the container
    echo "Starting the container..."
    pct start $CT_ID
    echo "Container started successfully."

    # Install dependencies inside the container
    echo "Installing dependencies inside the container..."
    pct exec $CT_ID -- apt-get update
    pct exec $CT_ID -- apt-get install -y curl sudo
    echo "Dependencies installed successfully inside the container."

    echo "All steps completed successfully."
}

# Call the function to create LXC container with custom template and install dependencies
create_container_with_custom_template_and_dependencies

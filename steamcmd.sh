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

    # Update and upgrade the system
    echo "Updating system..."
    apt-get update &>/dev/null
    apt-get -y upgrade &>/dev/null
    echo "System updated."

    # Select LXC template
    LXC_TEMPLATE=$(pct list templates | grep -i "$SEARCH_TERM" | cut -d' ' -f1 | whiptail --menu "Select LXC template:" 15 78 4 3>&1 1>&2 2>&3)
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

    # Wait for container to start
    sleep 5

    # Check if DHCP is not selected
    if [ "$DHCP" != "yes" ]; then
        # Configure static IP
        echo "Configuring static IP..."
        pct exec $CT_ID ip addr add $IP_ADDRESS/24 dev eth0
        pct exec $CT_ID ip route add default via 192.168.1.1
        echo "Static IP configured."
    fi

    # Install SSH server
    echo "Installing SSH server..."
    pct exec $CT_ID apt-get update
    pct exec $CT_ID apt-get install -y openssh-server
    pct exec $CT_ID systemctl enable ssh
    pct exec $CT_ID systemctl start ssh
    echo "SSH server installed."

    # Ask user for FTP installation
    FTP_SELECTION=$(whiptail --menu "Select FTP installation:" 15 78 2 "FTP" "Install FTP" "None" "Do not install FTP" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "FTP Selection: $FTP_SELECTION"

    # Check if FTP is selected
    if [ "$FTP_SELECTION" == "FTP" ]; then
        # Get user input for FTP port
        FTP_PORT=$(get_input "FTP Port" "Enter the FTP port:" "21")
        if [ $? -ne 0 ]; then
            exit 1
        fi
        echo "FTP Port: $FTP_PORT"

        # Install FTP server
        echo "Installing FTP server..."
        pct exec $CT_ID apt-get install -y ftpd
        pct exec $CT_ID sed -i "s/listen=NO/listen=YES/" /etc/vsftpd.conf
        pct exec $CT_ID sed -i "s/#listen_ipv6=YES/listen_ipv6=NO/" /etc/vsftpd.conf
        pct exec $CT_ID sed -i "s/listen_port=21/listen_port=$FTP_PORT/" /etc/vsftpd.conf
        pct exec $CT_ID systemctl enable ftpd
        pct exec $CT_ID systemctl start ftpd
        echo "FTP server installed."
    fi

    # Output summary
    echo "-------------------------"
    echo "Container ID: $CT_ID"
    echo "Hostname: $HOSTNAME"
    echo "Storage: $STORAGE"
    echo "Root Password: $PASSWORD"
    echo "CPU Cores: $CORE_COUNT"
    echo "RAM Size: $RAM_SIZE MB"
    if [ "$DHCP" == "yes" ]; then
        echo "IP Address: DHCP"
    else
        echo "IP Address: $IP_ADDRESS"
    fi
    if [ "$SSH_STATUS" == "active" ]; then
        echo "SSH Access: Enabled (username: root, port: 22)"
    else
        echo "SSH Access: Disabled"
    fi
    if [ "$FTP_SELECTION" == "FTP" ]; then
        echo "FTP Access: Enabled (username: root, port: $FTP_PORT)"
    else
        echo "FTP Access: Disabled"
    fi
}

# Run the function to create container
create_container_with_custom_template_and_dependencies

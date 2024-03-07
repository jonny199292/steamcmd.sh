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

    # Ask user for SSH installation
    SSH_SELECTION=$(whiptail --menu "Select SSH installation:" 15 78 2 "SSH" "Install SSH" "None" "Do not install SSH" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "SSH Selection: $SSH_SELECTION"

    # Check if SSH is selected
    if [ "$SSH_SELECTION" == "SSH" ]; then
        # Get user input for SSH port
        SSH_PORT=$(get_input "SSH Port" "Enter the SSH port:" "22")
        if [ $? -ne 0 ]; then
            exit 1
        fi
        echo "SSH Port: $SSH_PORT"

        # Install SSH server
        echo "Installing SSH server..."
        pct exec $CT_ID -- apt-get update
        pct exec $CT_ID -- apt-get install -y openssh-server
        pct exec $CT_ID -- sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
        echo "SSH server installed."
    fi

    # Check if DHCP is not selected
    if [ "$DHCP" != "yes" ]; then
        # Configure static IP
        echo "Configuring static IP..."
        pct exec $CT_ID -- ip addr add $IP_ADDRESS/24 dev eth0
        pct exec $CT_ID -- ip route add default via 192.168.1.1
        echo "Static IP configured."
    fi

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
        pct exec $CT_ID -- apt-get update
        pct exec $CT_ID -- apt-get install -y ftpd
        pct exec $CT_ID -- sed -i "s/listen=NO/listen=YES/" /etc/vsftpd.conf
        pct exec $CT_ID -- sed -i "s/#listen_ipv6=YES/listen_ipv6=NO/" /etc/vsftpd.conf
        pct exec $CT_ID -- sed -i "s/listen_port=21/listen_port=$FTP_PORT/" /etc/vsftpd.conf
        echo "FTP server installed."
    fi

    # Check if Steam service is running
    STEAM_STATUS=$(pct exec $CT_ID -- systemctl is-active steam)
    if [ "$STEAM_STATUS" == "active" ]; then
        echo "Steam service is running."
    else
        echo "Steam service is not running."
    fi

    # Check if SSH service is running
    SSH_STATUS=$(pct exec $CT_ID -- systemctl is-active ssh)
    if [ "$SSH_STATUS" == "active" ]; then
        echo "SSH service is running."
    else
        echo "SSH service is not running."
    fi

    # Check if FTP service is running
    FTP_STATUS=$(pct exec $CT_ID -- systemctl is-active ftpd)
    if [ "$FTP_STATUS" == "active" ]; then
        echo "FTP service is running."
    else
        echo "FTP service is not running."
    fi

    # Output summary
    echo "-------------------------"
    echo "Container ID: $CT_ID"
    echo "Hostname: $HOSTNAME"
    echo "IP Address: $IP_ADDRESS"
    echo "Root Password: $PASSWORD"
    if [ "$SSH_SELECTION" == "SSH" ]; then
        echo "SSH Access: Enabled (username: root, port: $SSH_PORT)"
    else
        echo "SSH Access: Disabled"
    fi
    if [ "$FTP_SELECTION" == "FTP" ]; then
        echo "FTP Access: Enabled (username: root, port: $FTP_PORT)"
    else
        echo "FTP Access: Disabled"
    fi
}

# Call the function to create LXC container with custom template and install dependencies
create_container_with_custom_template_and_dependencies

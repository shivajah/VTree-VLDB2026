#!/bin/bash
set -e

# EC2 EBS volume setup: format, mount, fstab, install Java 21
# Usage: ./setup-ebs.sh [device]   e.g. ./setup-ebs.sh /dev/nvme1n1

get_data_device() {
    if [ -n "$1" ]; then
        echo "$1"
        return
    fi

    ROOT_DEV=$(findmnt / -o SOURCE -n 2>/dev/null | sed 's/p[0-9]*$//' | sed 's/[0-9]*$//')

    for dev in /dev/nvme*n1; do
        [ -b "$dev" ] || continue
        [[ "$dev" == "${ROOT_DEV}"* ]] && continue
        [[ "$ROOT_DEV" == *"nvme0"* && "$dev" == "/dev/nvme0n1" ]] && continue
        echo "$dev"
        return
    done

    echo ""
}

DEVICE="${1:-$(get_data_device)}"

if [ -z "$DEVICE" ] || [ ! -b "$DEVICE" ]; then
    echo "Usage: $0 [device]"
    echo "Example: $0 /dev/nvme1n1"
    echo ""
    echo "Available block devices:"
    lsblk -d -o NAME,SIZE,MODEL,MOUNTPOINT
    echo ""
    echo "Common EBS mappings: /dev/sdf -> nvme1n1, /dev/sdg -> nvme2n1"
    exit 1
fi

echo "Using device: $DEVICE"

# 1. Create XFS filesystem
sudo mkfs -t xfs "$DEVICE"

# 2. Create mount point
sudo mkdir -p /mnt/instance

# 3. Mount
sudo mount "$DEVICE" /mnt/instance

# 4. Get UUID and add to fstab
UUID=$(sudo blkid -s UUID -o value "$DEVICE")
if [ -z "$UUID" ]; then
    echo "Error: Could not get UUID for $DEVICE"
    exit 1
fi

FSTAB_ENTRY="UUID=${UUID}  /mnt/instance  xfs  defaults,nofail  0  2"
if grep -q "/mnt/instance" /etc/fstab; then
    echo "fstab entry for /mnt/instance already exists"
else
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
fi

# 5. Install Java 21 Amazon Corretto
sudo yum install -y java-21-amazon-corretto-devel

echo "Done! $DEVICE mounted at /mnt/instance, Java 21 installed."

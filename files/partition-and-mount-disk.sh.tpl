#!/bin/bash

disk="${data_volume_device}"

# Check if the disk already has partitions
partitions=$(lsblk -n -o NAME $disk | grep -oE '[[:digit:]]')
if [[ -n $partitions ]]; then
    echo "Disk $disk already has partitions. Exiting."
    exit 1
fi

# Partition the disk with a single partition using all available space
echo -e "o\ny\nn\n1\n\n\n0700\nw\ny" | gdisk $disk

# Format the partition with xfs file system
partition="$${disk}1"
mkfs.xfs $partition

# Mount the partition
mount_point="${data_volume_mount_path}"
mkdir -p $mount_point
echo "$partition $mount_point xfs defaults 0 0" >> /etc/fstab
mount -a

#!/bin/bash

set -e

DISK="/dev/nvme0n1"

formating_internal_disk() {
    echo "Unmounting any existing partitions..."
    umount ${DISK}* 2>/dev/null

    echo "Creating partitions on $DISK..."
    sgdisk -Z "$DISK" # Zap the disk (wipe GPT and MBR)
    sgdisk -o "$DISK" # Create a new GPT partition table
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" "$DISK" # EFI system partition
    sgdisk -n 2:0:+8G -t 2:8200 -c 2:"Linux Swap" "$DISK"    # Swap Partition (8 GB)
    sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux Root" "$DISK" # Root Partition (remaining space)

    echo "Formatting partitions..."
    mkfs.fat -F32 "${DISK}p1" 	# EFI System Partition
    mkswap "${DISK}p2" 		# Swap Partition
    mkfs.ext4 "${DISK}p3"	# Root Partition

    echo "Mounting partitions..."
    mount "${DISK}p3" /mnt
    mount --mkdir "${DISK}p1" /mnt/boot

    echo "Enabling swap..."
    swapon "${DISK}p2"

    echo "Partitioning and formatting complete. Layout:"
    lsblk "$DISK"
}

installing_essential_packages() {
    pacstrap -K /mnt base linux linux-firmware amd-ucode intel-ucode btrfs-progs e2fsprogs xfsprogs dosfstools ntfs-3g dhcpcd iwd networkmanager mesa vulkan-radeon vulkan-mesa-layers vulkan-tools xf86-video-amdgpu sof-firmware steam gamescope xorg-server libinput plasma-meta sddm kwin tlp linux-zen nano man-db man-pages base-devel grub efibootmgr bash-completion refind
}

configure_system() {
    genfstab -U /mnt >> /mnt/etc/fstab

    # Chrooting into installation
    arch-chroot /mnt
    echo "Disabling root password"
    passwd -d root
    # Setting up clock (Europe/Paris by default)
    ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
    hwclock --systohc
    echo "Generating locales..."
    sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    locale-gen
    echo "Setting up hostname..."
    echo "woodlouse" > /etc/hostname
    echo "Installation of reFind (bootloader)"
    refind-install
    echo "Exiting chroot"
    exit
    echo "Unmounting partitions..."
    umount -R /mnt
    echo "Done!\pWe're now gonna reboot in 5 seconds."
    wait 5
    reboot
}

echo "Starting Arch Linux installation for SteamDeck."
echo "\nFormating the internal disk."
read -p "Are you sure? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
    formating_internal_disk
    installing_essential_packages
    configure_system
fi


#!/bin/bash

set -e

DISK="/dev/nvme0n1"
BOOT_PART="${DISK}p1"
SWAP_PART="${DISK}p2"
ROOT_PART="${DISK}p3"

formating_internal_disk() {
    echo "Unmounting any existing partitions..."
    # Check if any partitions on the disk are mounted
    if mount | grep -q "${DISK}"; then
        # If mounted, unmount the partitions
        echo "Unmounting partitions on ${DISK}..."
        umount ${DISK}* 2>/dev/null
    else
        echo "No partitions are mounted on ${DISK}."
    fi
    echo "Creating partitions on $DISK..."
    sgdisk -Z "$DISK" # Zap the disk (wipe GPT and MBR)
    sgdisk -o "$DISK" # Create a new GPT partition table
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" "$DISK" # EFI system partition
    sgdisk -n 2:0:+8G -t 2:8200 -c 2:"Linux Swap" "$DISK"    # Swap Partition (8 GB)
    sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux Root" "$DISK" # Root Partition (remaining space)

    echo "Formatting partitions..."
    mkfs.fat -F32 "${BOOT_PART}"        # EFI System Partition
    mkswap "${SWAP_PART}"               # Swap Partition
    mkfs.ext4 "${ROOT_PART}"            # Root Partition

    echo "Mounting partitions..."
    mount "${ROOT_PART}" /mnt
    mount --mkdir "${BOOT_PART}" /mnt/boot

    echo "Enabling swap..."
    swapon "${SWAP_PART}"

    echo "Partitioning and formatting complete. Layout:"
    lsblk "$DISK"
}

installing_essential_packages() {
#    pacstrap -K /mnt base linux linux-firmware amd-ucode intel-ucode btrfs-progs e2fsprogs xfsprogs dosfstools ntfs-3g dhcpcd iwd networkmanager mesa vulkan-radeon vulkan-mesa-layers vulkan-tools xf86-video-amdgpu sof-firmware steam gamescope xorg-server libinput plasma-meta sddm kwin tlp linux-zen nano man-db man-pages base-devel grub efibootmgr bash-completion refind
    pacstrap -K /mnt base linux linux-firmware
}

configure_system() {
    genfstab -U /mnt >> /mnt/etc/fstab

    # Chrooting into installation
    arch-chroot /mnt /bin/bash <<"EOT"
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
    echo "Enabling multilib support..."
    # Enabling multilib repo in pacman.conf
    sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
    sed -i 's/^#Include = \/etc\/pacman.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf
    pacman -Syu --noconfirm amd-ucode intel-ucode btrfs-progs e2fsprogs xfsprogs dosfstools ntfs-3g dhcpcd iwd networkmanager mesa vulkan-radeon vulkan-mesa-layers vulkan-tools xf86-video-amdgpu sof-firmware steam gamescope xorg-server libinput plasma-meta sddm kwin tlp linux-zen nano man-db man-pages base-devel grub efibootmgr bash-completion refind lutris
    echo "Installation of reFind (bootloader)"
    refind-install
    exit
    echo $$
    EOT

    echo "Unmounting partitions..."
    umount -R /mnt
    echo "Done!\pWe're now gonna reboot in 5 seconds."
    wait 5
    reboot
}

echo "Starting Arch Linux installation for SteamDeck."
echo "Formating the internal disk."
echo "Press Enter to continue, or type 'n' to cancel."
# Read user input and check if it's empty (just Enter) or 'n'/'N'
read -r REPLY
if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
    formating_internal_disk
    installing_essential_packages
    configure_system
else
    echo "Operation canceled."
    exit 1
fi

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
    pacstrap -K /mnt base linux linux-firmware
}

configure_system() {
    genfstab -U /mnt >> /mnt/etc/fstab

    # Chrooting into installation
    arch-chroot /mnt /bin/bash <<"EOT"
    echo "Disabling root password"
    passwd -d root
    echo "Creating user deck..."
    useradd -m -G wheel deck
    passwd -d deck
    # Activer sudo pour le groupe wheel
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
    # Réglage du clavier en français par défaut
    echo "Setting French keyboard layout..."
    echo "KEYMAP=fr" > /etc/vconsole.conf
    # Setting up clock (Europe/Paris by default)
    ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
    hwclock --systohc
    # Locales
    echo "Generating locales..."
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sed -i 's/^#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    echo "Setting up hostname..."
    echo "woodlouse" > /etc/hostname
    echo "Enabling multilib support..."
    # Activation de multilib
    echo "Enabling multilib repository in pacman.conf..."
    sed -i '/^\[multilib\]$/,/^Include/{s/^#//}' /etc/pacman.conf
    pacman -Syu --noconfirm amd-ucode intel-ucode btrfs-progs e2fsprogs xfsprogs dosfstools ntfs-3g dhcpcd iwd networkmanager mesa vulkan-radeon vulkan-mesa-layers vulkan-tools xf86-video-amdgpu sof-firmware steam gamescope xorg-server libinput plasma-meta sddm kwin tlp linux-zen nano man-db man-pages base-devel bash-completion grub efibootmgr lutris konsole vi
    #echo "Installing yay (AUR helper)..."
    #git clone https://aur.archlinux.org/yay.git /tmp/yay
    #cd /tmp/yay
    #makepkg -si --noconfirm
    # Installation d'opengamepadui-bin via AUR
    #echo "Installing opengamepadui-bin (AUR)..."
    #yay -S --noconfirm opengamepadui-bin
    echo "Installation of GRUB (bootloader)"
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    # Activer dhcpcd au démarrage
    echo "Enabling dhcpcd service..."
    systemctl enable dhcpcd.service
    systemctl start dhcpcd.service
    exit
    echo $$
EOT

    echo "Unmounting partitions..."
    umount -R /mnt
    echo "Done!"
    echo "We're now gonna reboot in 5 seconds."
    sleep 5
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

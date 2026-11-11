#!/bin/sh
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "EROARE: Ruleaza acest script ca 'root' de pe Live ISO!"
    exit 1
fi

clear
echo "================================================================="
echo "     INSTALATOR INTERACTIV CHIMERA LINUX + HYPRLAND (BTRFS)      "
echo "================================================================="
echo ""

# 1. Alegere Disc
echo "--- Discuri disponibile pe sistem ---"
lsblk -d -p -n -o NAME,SIZE,MODEL | grep -v "loop" || lsblk
echo "-------------------------------------"
printf "Introdu discul tinta [default: /dev/nvme0n1]: "
read -r DISK
DISK=${DISK:-/dev/nvme0n1}

if [ ! -b "$DISK" ]; then
    echo "EROARE: Discul $DISK nu exista!"
    exit 1
fi

# 2. Hostname
printf "Numele calculatorului (Hostname) [default: chimera]: "
read -r HOSTNAME
HOSTNAME=${HOSTNAME:-chimera}

# 3. Utilizator si Parole
printf "Numele tau de utilizator [default: utilizator]: "
read -r USERNAME
USERNAME=${USERNAME:-utilizator}

while true; do
    printf "Parola pentru %s: " "$USERNAME"
    stty -echo
    read -r USER_PASS
    stty echo
    echo ""
    printf "Confirma parola pentru %s: " "$USERNAME"
    stty -echo
    read -r USER_PASS2
    stty echo
    echo ""
    [ "$USER_PASS" = "$USER_PASS2" ] && [ -n "$USER_PASS" ] && break
    echo "Parolele nu coincid sau sunt goale! Incearca din nou."
done

while true; do
    printf "Parola de administrator (root): "
    stty -echo
    read -r ROOT_PASS
    stty echo
    echo ""
    printf "Confirma parola de root: "
    stty -echo
    read -r ROOT_PASS2
    stty echo
    echo ""
    [ "$ROOT_PASS" = "$ROOT_PASS2" ] && [ -n "$ROOT_PASS" ] && break
    echo "Parolele nu coincid sau sunt goale! Incearca din nou."
done

# 4. Regiune / Timezone
printf "Regiune / Fus orar (ex: Europe/Bucharest, Europe/Stockholm) [default: Europe/Bucharest]: "
read -r TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Bucharest}

# 5. Limba sistemului (Locale)
printf "Limba sistemului (ex: ro_RO.UTF-8, en_US.UTF-8) [default: ro_RO.UTF-8]: "
read -r LOCALE
LOCALE=${LOCALE:-ro_RO.UTF-8}

# 6. Tastatura (Keyboard Layout)
printf "Layout tastatura (ex: ro, us, se, de) [default: ro]: "
read -r KB_LAYOUT
KB_LAYOUT=${KB_LAYOUT:-ro}

# 7. Placa Video (GPU)
echo ""
echo "Selecteaza placa ta video:"
echo "  1) AMD (Open-Source Mesa - Recomandat)"
echo "  2) Intel (Open-Source Mesa)"
echo "  3) NVIDIA (Drivere proprietare + configurare Wayland)"
printf "Alege optiunea (1/2/3) [default: 1]: "
read -r GPU_CHOICE
GPU_CHOICE=${GPU_CHOICE:-1}

case "$GPU_CHOICE" in
    3)
        GPU_PKGS="nvidia nvidia-dkms linux-lts-headers"
        GPU_NAME="NVIDIA"
        ;;
    2)
        GPU_PKGS="mesa-dri vulkan-loader mesa-vulkan-intel intel-media-driver"
        GPU_NAME="Intel"
        ;;
    *)
        GPU_PKGS="mesa-dri vulkan-loader mesa-vulkan-radeon"
        GPU_NAME="AMD"
        ;;
esac

# Sumar & Confirmare finala
clear
echo "================================================================="
echo "               REZUMAT INSTALARE (VERIFICA DATELE)               "
echo "================================================================="
echo "  Disc tinta      : $DISK (TOATE DATELE VOR FI STERSE!)"
echo "  Hostname        : $HOSTNAME"
echo "  Utilizator      : $USERNAME"
echo "  Fus orar        : $TIMEZONE"
echo "  Limba (Locale)  : $LOCALE"
echo "  Tastatura       : $KB_LAYOUT"
echo "  Placa Video     : $GPU_NAME"
echo "  Filesystem      : Btrfs (@, @home, @snapshots, @cache, @log)"
echo "  Bootloader      : Limine (Auto-sync kernel)"
echo "  Desktop         : Hyprland Modular Clean + Catppuccin Greeter"
echo "================================================================="
printf "Scrie 'DA' (cu majuscule) pentru a incepe instalarea: "
read -r CONFIRM
if [ "$CONFIRM" != "DA" ]; then
    echo "Instalare anulata."
    exit 1
fi

case "$DISK" in
    *nvme*|*mmcblk*)
        PART1="${DISK}p1"
        PART2="${DISK}p2"
        ;;
    *)
        PART1="${DISK}1"
        PART2="${DISK}2"
        ;;
esac

echo "=== [1/8] Partitionare disc ($DISK) ==="
sfdisk --wipe always "$DISK" << EOF
label: gpt
size=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF
sleep 2

echo "=== [2/8] Formatare si creare subvolume Btrfs (Optimizat SSD) ==="
mkfs.fat -F32 "$PART1"
mkfs.btrfs -f "$PART2"

mount "$PART2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
umount /mnt

mkdir -p /media/root
mount -o compress=zstd,noatime,subvol=@ "$PART2" /media/root
chmod 755 /media/root

mkdir -p /media/root/home /media/root/.snapshots /media/root/boot /media/root/var/cache/apk /media/root/var/log
mount -o compress=zstd,noatime,subvol=@home "$PART2" /media/root/home
mount -o compress=zstd,noatime,subvol=@snapshots "$PART2" /media/root/.snapshots
mount -o compress=zstd,noatime,subvol=@cache "$PART2" /media/root/var/cache/apk
mount -o compress=zstd,noatime,subvol=@log "$PART2" /media/root/var/log
mount -o umask=0077 "$PART1" /media/root/boot

echo "=== [3/8] Instalare sistem de baza Chimera (Bootstrap) ==="
chimera-bootstrap /media/root
genfstab -U /media/root >> /media/root/etc/fstab
sed -i 's|\(/boot[[:space:]]\+vfat[[:space:]]\+[^[:space:]]*\)|\1,umask=0077|' /media/root/etc/fstab

BTRFS_UUID=$(blkid -s UUID -o value "$PART2")

echo "=== [4/8] Configurare sistem, Locale, Kernel & Limine ==="
cat << EOF > /media/root/root/chroot_setup.sh
#!/bin/sh
set -e

apk update
apk upgrade --available
apk add chimera-repo-user
apk update

# Kernel, Bootloader, Btrfs, Drivere GPU & Retea
apk add linux-lts btrfs-progs limine efibootmgr nano curl $GPU_PKGS

# Hostname, Timezone, Locale & Tastatura consola
echo "$HOSTNAME" > /etc/hostname
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KB_LAYOUT" > /etc/vconsole.conf

# Parole si Utilizator
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel,video,input,audio,plugdev "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd

# Servicii de baza Dinit
dinitctl enable syslog-ng
dinitctl enable networkmanager
dinitctl enable dbus
dinitctl enable udev

KERNEL_EXTRA=""
if [ "$GPU_CHOICE" = "3" ]; then
    KERNEL_EXTRA="nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
fi

update-initramfs -c -k all
mkdir -p /boot/EFI/limine
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/
efibootmgr --create --disk "$DISK" --part 1 --label "Chimera Limine" --loader '\EFI\limine\BOOTX64.EFI' || true

cat << 'EOS' > /usr/local/bin/update-limine
#!/bin/sh
set -e
VMLINUZ=\$(ls -1 /boot/vmlinuz-* 2>/dev/null | sort -V | tail -n 1 | xargs -r basename)
INITRAMFS=\$(ls -1 /boot/initramfs-*.img 2>/dev/null | sort -V | tail -n 1 | xargs -r basename)

if [ -z "\$VMLINUZ" ] || [ -z "\$INITRAMFS" ]; then
    echo "EROARE: Nu am gasit kernel-ul in /boot!"
    exit 1
fi

cat << EOL > /boot/limine.conf
timeout: 3

/Chimera Linux
    protocol: linux
    kernel_path: boot():/\$VMLINUZ
    module_path: boot():/\$INITRAMFS
    cmdline: root=UUID=$BTRFS_UUID rw rootflags=subvol=@ $KERNEL_EXTRA
EOL
echo "Limine actualizat cu kernel-ul: \$VMLINUZ"
EOS
chmod +x /usr/local/bin/update-limine
/usr/local/bin/update-limine

echo "=== [5/8] Configurare Snapper (0 MB RAM, max 10% SSD) & Cron ==="
apk add snapper cronie cronie-dinit

umount /.snapshots
rmdir /.snapshots
snapper -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a

cat << 'EOS' > /etc/snapper/configs/root
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.1"
FREE_LIMIT="0.2"
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="4"
NUMBER_LIMIT_IMPORTANT="4"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="3"
TIMELINE_LIMIT_DAILY="4"
TIMELINE_LIMIT_WEEKLY="1"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
EOS

dinitctl enable cronie

cat << 'EOS' > /etc/cron.hourly/snapper
#!/bin/sh
snapper --config root create --cleanup-algorithm timeline --description "timeline"
EOS

cat << 'EOS' > /etc/cron.daily/snapper
#!/bin/sh
snapper --config root cleanup timeline
snapper --config root cleanup number
EOS

cat << 'EOS' > /etc/cron.weekly/fstrim
#!/bin/sh
fstrim -av
EOS

cat << 'EOS' > /etc/rc.local
#!/bin/sh
snapper -c root create --description "Boot snapshot" --cleanup-algorithm number
snapper -c root cleanup number
EOS

cat << 'EOS' > /usr/local/bin/sysup
#!/bin/sh
set -e
PRE=\$(snapper -c root create --type pre --cleanup-algorithm number --print-number --description "apk upgrade")
apk update
apk upgrade "\$@"
/usr/local/bin/update-limine
snapper -c root create --type post --pre-number "\$PRE" --cleanup-algorithm number --description "apk upgrade"
snapper -c root cleanup number
EOS

chmod +x /etc/cron.hourly/snapper /etc/cron.daily/snapper /etc/cron.weekly/fstrim /etc/rc.local /usr/local/bin/sysup

echo "=== [6/8] Securizare Sistem (Firewall UFW & Kernel Hardening) ==="
apk add ufw ufw-dinit
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
dinitctl enable ufw

cat << 'EOS' > /etc/sysctl.d/99-security.conf
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
EOS

echo "=== [7/8] Instalare Hyprland, Utilitati & Greetd (Tema Catppuccin) ==="
apk add hyprland xdg-desktop-portal-hyprland hyprpaper hyprlock hypridle \
    waybar fuzzel mako grim slurp wl-clipboard brightnessctl playerctl pamixer pavucontrol \
    foot pipewire wireplumber polkit polkit-gnome network-manager-applet \
    thunar thunar-volman thunar-archive-plugin gvfs file-roller \

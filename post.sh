#!/usr/bin/env sh
set -eu

if [ "$(whoami)" = root ]; then
	echo "This script is not to be run as root!"
	exit
fi

systemctl status NetworkManager.service | grep running || {
	sudo systemctl start NetworkManager.service
	sudo systemctl enable NetworkManager.service
}

ping -c 1 archlinux.org || sudo nmtui

# replace the mirrors from reflector since they're not very good

# curl -s "https://archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4&ip_version=6" |
# 	sed -r 's|^#Server|Server|' |
# 	sudo tee /etc/pacman.d/mirrorlist

sudo pacman -Syu

# https://www.davidtsadler.com/posts/installing-st-dmenu-and-dwm-in-arch-linux/
sudo pacman -S base-devel libx11 libxft xorg-server xorg-xinit terminus-font libxinerama rxvt-unicode ranger firefox

cd
git clone https://github.com/hejops/dwm
cd dwm
make clean
sudo make install

cat << EOF > "$HOME/.xinitrc"
export PATH=\$PATH:\$HOME/.local/bin
xrdb -merge ~/.Xresources
dwm
EOF

# https://wiki.archlinux.org/title/Xinit#Autostart_X_at_login
# https://unix.stackexchange.com/a/521049
# apparently, .bash_profile is tried by default, while .profile is totally ignored
# why does this EOF have single quotes? i honestly forgot

cat << 'EOF' > "$HOME/.bash_profile"
if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
	exec startx
fi
EOF

cat << EOF
Successfully configured dwm
dwm will be started automatically after logging back in
EOF

# pkill bash

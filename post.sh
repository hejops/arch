#!/usr/bin/env sh
set -eu

[ "$(whoami)" != joseph ] && exit

# installs a bare minimum graphical environment after a successful install

# TODO: the service should be enabled from archiso
systemctl status NetworkManager.service | grep running || {
	systemctl start NetworkManager.service
	systemctl enable NetworkManager.service
}

ping -c 1 archlinux.org || nmtui

# https://www.davidtsadler.com/posts/installing-st-dmenu-and-dwm-in-arch-linux/
sudo pacman -S base-devel libx11 libxft xorg-server xorg-xinit terminus-font libxinerama rxvt-unicode ranger

cd
git clone https://github.com/hejops/dwm
cd dwm
make clean
sudo make install

echo dwm >"$HOME/.xinitrc"

cat <<EOF >"$HOME/.profile"
if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
	exec startx
fi
EOF

cat <<EOF
Installed dwm
dwm will be started automatically after logging back in
EOF

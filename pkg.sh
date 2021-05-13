#!/usr/bin/env bash
# bash is required for arrays
set -euo pipefail

# exit

usage() {
cat << EOF
Usage: $(basename "$0") [options]

EOF
exit
}

# [[ $# -eq 0 ]] && usage
[[ ${1:-} = --help ]] && usage

# TODO: determine package manager
PKGMGR=pacman
INSTALL="sudo pacman -S"
QUERY="pacman -Ss"
AURINSTALL="trizen --get"
PIPINSTALL="pip3 install"

# set mirror

# all packages here are confirmed on pacman
# ubuntu installs have lower priority, and user is expected to find missing packages themselves
MAIN=(

ack
curl
dash
feh
ffmpeg
firefox
flameshot
fzf
gnupg
groff
htop
i3lock
libnotify
maim
make
moreutils
mpc
mpd
mpv
ncmpcpp
neomutt
newsboat
nodejs
notmuch
offlineimap
pavucontrol
pcre
picom
python-pdftotext
python3
ranger
recode
rofi
rxvt-unicode
shellcheck
shfmt
socat
telegram-desktop
texlive-bin
texlive-core
trizen
udiskie
udisks2
vim
xdg-utils
xorg-xbacklight
xorg-xinit
xorg-xrandr
xournalpp
youtube-dl
zathura-pdf-mupdf
zathura-ps

)
# jupyter-core

# ?lightdm -- https://wiki.archlinux.org/index.php/Display_manager#Console
# no diplay manager: .xinitrc (exec dwm)
# try out on new thinkpad

sudo pacman -Syu
$INSTALL "${MAIN[@]}"

# if [[ $PKGMGR = pacman ]]; then
# 	:
# else
# 	FOUND=()
# 	# this is quite inefficient...
# 	for pkg in "${MAIN[@]}"; do
# 		if $QUERY "^$pkg$"; then
# 			FOUND+=("$pkg")	# MAIN-= is not allowed
# 		else
# 			echo "$pkg" >> packages_notfound
# 		fi
# 	done
# 	echo "${FOUND[@]}"
# 	exit
# 	$INSTALL "${FOUND[@]}"
# fi
# # for each line in packages_notfound, suggest an alternative

exit

# echo "Install miscellaneous packages? [y/N]"
# read -rp "If this is a work system, they are probably unnecessary. " ans < /dev/tty

SERVICES=(

mbsync
mpd

)

systemctl enable
systemctl start

systemctl enable --user mbsync.timer
systemctl start --user mbsync.timer
# systemctl status

AUR=(

discord-ptb
gruvbox-dark-gtk
htop-vim
lowdown
playitslowly
font-manager
tllocalmgr-git
urxvt-perls

)

$AURINSTALL

# installed to .local/bin by default; this is included in $PATH
PIPS=(

	biopython
	jupytext
	lastpy
	modlamp
	rope
	vim-vint
)

$PIPINSTALL

jupyter nbextension install --py jupytext --user
jupyter nbextension enable --py jupytext --user

# set up credentials
GIT=(
dwm
dotfiles
scripts
)

# mv dotfiles up

# create passwords for mail, lastfm
mkpass "$HOME/.passwd/gmail.gpg"
mkpass "$HOME/.passwd/lastfm.gpg"

mbsync -Va #&
# if HDD connected, start building mpd database & (takes a long time)

unsf -- sudo make -f Makefile.linux install

xdg-open https://github.com/hejops/dotfiles/raw/master/.mozilla/firefox/4clnophl.default/chrome/google.user.css
# stylus only accepts urls, not files

cp /usr/share/applications/ranger.desktop "$HOME/.local/share/applications"

# fonts are set in: .Xresources, firefox, rofi, dwm, .config/gtk-3.0/settings.ini
# set xdgs -- ~/.config/mimeapps.list
https://github.com/mwh/dragon
set xdgs:
xdg-mime default org.pwmt.zathura.desktop application/pdf
xdg-mime default ranger.desktop inode/directory
xdg-mime default vim.desktop text/plain + https://unix.stackexchange.com/a/231302

echo "The following packages were not found on $PKGMGR. Please resolve them yourself."
cat packages_notfound

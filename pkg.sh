#!/usr/bin/env bash
# bash is required for arrays
set -euo pipefail

PKGMGR=pacman
INSTALL="sudo pacman -S"
QUERY="pacman -Ss"
AURINSTALL="trizen --get"
PIPINSTALL="pip3 install"

MAIN=(

	ack
	cronie
	curl
	dash
	exa
	feh
	ffmpeg
	firefox
	flameshot
	fzf
	gnupg
	groff
	htop
	hunspell
	i3lock
	inetutils
	isync
	libnotify
	maim
	make
	man
	moreutils
	mpc
	mpd
	mpv
	ncmpcpp
	neomutt
	newsboat
	nodejs
	notmuch
	npm
	pavucontrol
	pcre
	picom
	python-pdftotext
	python3
	ranger
	recode
	rofi
	rsync
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

# TODO: chown arch

asoundconf list
# HDMI is usually not what we want
asoundconf set-default-card PCH
amixer sset Master unmute
echo "Testing sound..."
speaker-test -c 2 -D plughw:1

# sudo pacman -Sy --needed base-devel git
git clone https://aur.archlinux.org/trizen.git
cd trizen
sudo makepkg -si
cd

fix_pacman_keys() {
	# https://bbs.archlinux.org/viewtopic.php?pid=1984300#p1984300
	# enable ntp and ensure the time correct
	sudo timedatectl set-ntp 1
	timedatectl status

	# create pacman master key, reload keys from keyring resources
	sudo rm -fr /etc/pacman.d/gnupg
	sudo pacman-key --init
	sudo pacman-key --populate
}

fix_pacman_keys

sudo pacman -Syu
$INSTALL "${MAIN[@]}"

[[ -f "$HOME/.git-credentials" ]] || {
	git config --global credential.helper store
	xdg-open "https://github.com/settings/tokens/new"
	read -r -p "PAT: " PAT </dev/tty
	echo "https://hejops:$PAT@github.com" | tr -d ' ' | tee "$HOME/.git-credentials"
}

cd
git clone https://github.com/hejops/dotfiles
rm -rf "$HOME/.mozilla"
rsync -vua dotfiles/ .
xrdb -merge .Xresources

exit

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
	font-manager
	gruvbox-dark-gtk
	htop-vim
	lowdown
	playitslowly
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

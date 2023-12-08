#!/usr/bin/env bash
set -euo pipefail

# (cd)
# git clone https://github.com/hejops/arch (public)
# cd arch
# bash mac.sh

# homebrew is avoided at all costs

build() {

	:

	# build: macports nvim conda xcode

	# https://www.macports.org/install.php
	# https://github.com/macports/macports-base/releases/download/v2.8.0/MacPorts-2.8.0-13-Ventura.pkg

	# command -v port
	# /opt/local/bin/port

	# must redo after every system update...
	xcode-select --install || :

	# 'sudo xcodebuild -license' not required, apparently

}

# port: ranger lowdown shfmt npm? pcregrep pip?

# pip: black
# npm i -g: prettier bash-language-server

# IFS=" " read -r -a MAIN <<< "$(perl < ./packages_mac.txt -nle'print if m{^[^# 	]+}' | xargs)"

dotfiles() {

	# .bashrc
	# .bash_aliases
	# .vim

	dirs_to_copy=(

		kitty
		nvim
		ranger
		readline
		tridactyl
	)

	for x in "${dirs_to_copy[@]}"; do
		ln -sf ~/dotfiles/.config/"$x" ~/.config
	done

	exit

	# git config --global user.email hejops1@gmail.com
	# git config --global user.name Joseph

	# TODO: remove and stop tracking sensitive files:
	# .cron
	# ~/.config/nicotine
	# ~/.config/newsboat
	# ~/.config/tridactyl/tridactylrc

	if ! [[ -f "$HOME/.git-credentials" ]]; then
		git config --global credential.helper store
		echo "Setting up Github PAT..."
		open "https://github.com/settings/tokens/new" > /dev/null
		read -r -p "PAT: " PAT < /dev/tty
		echo "https://hejops:$PAT@github.com" |
			tr -d ' ' |
			tee "$HOME/.git-credentials"

		# get dotfiles and scripts

		cd
		git clone https://github.com/hejops/dotfiles

	fi

	rm -rf "$HOME/.mozilla"

	# delete most dirs in config (or rather, rsync select dirs out)

	# rsync -vua ~/dotfiles/ .
	# rm -r ~/dotfiles

	# xrdb -merge ~/.Xresources

	# fonts dir: /Library/Fonts

	# 1. get github token -- file transfer, or type manually
	# 2. git config --global credential.helper store
	# (else get password prompt, which is insecure/outdated)
	# 3. git clone https://github.com/hejops/dotfiles

}

dock_settings() {
	# removes nearly everything; the rest can be manually removed
	# defaults write com.apple.dock persistent-apps '()'

	# https://macos-defaults.com
	defaults write com.apple.dock "orientation" -string "left"
	defaults write com.apple.dock "show-recents" -bool "false"
	defaults write com.apple.dock "static-only" -bool "true"
	defaults write com.apple.dock "tilesize" -int "30"

	# keyboard shortcuts: terminal / ranger / firefox
	# autostart

	# # disable startup sound
	# sudo nvram StartupMute=%01

	# reverse scroll direction

}

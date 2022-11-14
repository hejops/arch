#!/usr/bin/env bash
set -euo pipefail

# (cd)
# git clone https://github.com/hejops/arch (public)
# cd arch
# bash mac.sh

# 1. get github token -- file transfer, or type manually
# 2. git config --global credential.helper store
# (else get password prompt, which is insecure/outdated)
# 3. git clone https://github.com/hejops/dotfiles

# must redo after every system update...
xcode-select --install || :

IFS=" " read -r -a MAIN <<< "$(perl < ./packages_mac.txt -nle'print if m{^[^# 	]+}' | xargs)"
brew install "${MAIN[@]}"

exit

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

# TODO: separate window?
vim

# cd
# git clone https://github.com/hejops/scripts
# bash ~/scripts/links ~/scripts

remove_dock_icons() {
	# https://stackoverflow.com/a/20695955

	# TODO: determine end condition

	sudo -u $USER /usr/libexec/PlistBuddy -c "Delete persistent-apps:0" ~/Library/Preferences/com.apple.dock.plist

	# dloc=$(defaults read com.apple.dock persistent-apps | grep file-label | awk '/Notes/  {printf NR}')
	# dloc=$((dloc - 1))
	# echo $dloc
	# sudo -u $USER /usr/libexec/PlistBuddy -c "Delete persistent-apps:$dloc" ~/Library/Preferences/com.apple.dock.plist

	# # must delete item from com.apple.dock.plist agian,or won't change
	# dloc=$(defaults read com.apple.dock persistent-apps | grep file-label | awk '/Photo Booth/  {printf NR}')
	# dloc=$((dloc - 1))
	# echo $dloc
	# sudo -u $USER /usr/libexec/PlistBuddy -c "Delete persistent-apps:$dloc" ~/Library/Preferences/com.apple.dock.plist

	sleep 3
	# Restart Dock to persist changes
	osascript -e 'delay 3' -e 'tell Application "Dock"' -e 'quit' -e 'end tell'
}

# TODO:

# keyboard shortcuts: terminal / ranger / firefox
# autostart

# # disable startup sound
# sudo nvram StartupMute=%01

# reverse scroll direction

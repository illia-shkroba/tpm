#!/usr/bin/env bash

# this script handles core logic of updating plugins

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS_DIR="$CURRENT_DIR/helpers"

source "$HELPERS_DIR/plugin_functions.sh"
source "$HELPERS_DIR/utility.sh"

if [ "$1" == "--tmux-echo" ]; then # tmux-specific echo functions
	source "$HELPERS_DIR/tmux_echo_functions.sh"
else # shell output functions
	source "$HELPERS_DIR/shell_echo_functions.sh"
fi

# from now on ignore first script argument
shift

pull_changes() {
	local plugin="$1"
	local branch="$2"
	local plugin_path="$(plugin_path_helper "$plugin")"
	(
		set -e

		cd "$plugin_path"
		export GIT_TERMINAL_PROMPT=0

		git fetch
		if [ -n "$branch" ]
		then
			git checkout "$branch"
			if git show-ref --quiet --branches "$branch"
			then
				git merge --ff-only
			fi
		else
			git pull
		fi
		git submodule update --init --recursive
	)
}

update() {
	local plugin="$1" output
	local branch="$2"
	output=$(pull_changes "$plugin" "$branch" 2>&1)
	if (( $? == 0 )); then
		echo_ok "  \"$plugin\" update success"
		echo_ok "$(echo "$output" | sed -e 's/^/    | /')"
	else
		echo_err "  \"$plugin\" update fail"
		echo_err "$(echo "$output" | sed -e 's/^/    | /')"
	fi
}

update_all() {
	echo_ok "Updating all plugins!"
	echo_ok ""
	local plugins="$(tpm_plugins_list_helper)"
	for plugin in $plugins; do
		IFS='#' read -ra plugin <<< "$plugin"
		local plugin_name="$(plugin_name_helper "${plugin[0]}")"
		local branch="${plugin[1]}"
		# updating only installed plugins
		if plugin_already_installed "$plugin_name"; then
			update "$plugin_name" "$branch" &
		fi
	done
	wait
}

update_plugins() {
	local plugins="$*"
	for plugin in $plugins; do
		IFS='#' read -ra plugin <<< "$plugin"
		local plugin_name="$(plugin_name_helper "${plugin[0]}")"
		local branch="${plugin[1]}"
		if plugin_already_installed "$plugin_name"; then
			update "$plugin_name" "$branch" &
		else
			echo_err "$plugin_name not installed!" &
		fi
	done
	wait
}

main() {
	ensure_tpm_path_exists
	if [ "$1" == "all" ]; then
		update_all
	else
		update_plugins "$*"
	fi
	exit_value_helper
}
main "$*"

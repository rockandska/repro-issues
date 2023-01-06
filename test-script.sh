#!/usr/bin/env bash
set -euo pipefail
tmux_repo="https://github.com/tmux/tmux.git"

[[ -n "${DEBUG:-}" ]] && set -x

source ~/.profile || true


if [[ ! -d ~/tmux-src/$v ]];then
	git clone -b "${v}" "${tmux_repo}" ~/tmux-src/$v
	cd ~/tmux-src/$v
	echo "Building tmux $v"
	sh autogen.sh
	./configure --prefix=$HOME/tmux-builds/tmux-$v && make && make install
	cd ~/
fi

export PATH=$HOME/tmux-builds/tmux-$v/bin:$PATH

#libtmux_repo="https://github.com/rockandska/libtmux.git"
#libtmux_branch="save_scroll"
#if [[ ! -d ~/libtmux ]];then
#	git clone -b "$libtmux_branch" "${libtmux_repo}" ~/libtmux
#fi
#
#if ! command -v pyenv &> /dev/null;then
#	curl https://pyenv.run | bash
#	PYENV=(
#		'export PYENV_ROOT="$HOME/.pyenv"'
#		'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
#		'eval "$(pyenv init -)"'
#		)
#
#	printf '%s\n' "${PYENV[@]}" >> ~/.profile
#	exec bash -l
#fi
#
#pyenv install -s 3.7
#pyenv local 3.7
#pip install -q poetry
#poetry -C ~/libtmux install
#poetry -C ~/libtmux run pytest ~/libtmux/tests/test_pane.py

echo "Showing tmux version in use"
tmux -V
echo "Killing sesion if present"
tmux kill-session &> /dev/null || true
echo "Creating new session"
tmux -v new-session -d -s test /usr/bin/env PS1="$ " sh
echo "Sending \"printf '%s'\" C-m"
tmux send-keys "printf '%s'" C-m

echo "Comparing expected vs output"
echo "----------------------------"
printf -v output '%s' "$(tmux capture-pane -p)"
sdiff <(echo "$output") <(cat <<-'TEST'
	$ printf '%s'
	$
	TEST
)
echo "----------------------------"

echo "Sending \"tput clear\" C-m"
tmux send-keys "tput clear" C-m

echo "Comparing expected vs output"
echo "----------------------------"
printf -v output '%s' "$(tmux capture-pane -p 2>&1)"
sdiff <(echo "$output") <(cat <<-'TEST'
	$
	TEST
)
echo "----------------------------"

echo "Comparing expected vs output with -S -2"
echo "----------------------------"
printf -v output '%s' "$(tmux capture-pane -p -S -2 2>&1)"
sdiff <(echo "$output") <(cat <<-'TEST'
	$ printf '%s'
	$ tput clear
	$
	TEST
)
echo "----------------------------"

echo "Comparing expected vs output with -E -"
echo "----------------------------"
printf -v output '%s' "$(tmux capture-pane -p -E - 2>&1)"
sdiff <(echo "$output") <(cat <<-'TEST'
	$
	TEST
)
echo "----------------------------"
echo "Finished"

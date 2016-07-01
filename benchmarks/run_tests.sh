#!/bin/bash

# run_tests.sh

# Description: setups a tmux session to run network benchmarks. It creates 2
# panes. The left one runs the main script that runs locally. The right pane
# creates a ssh session to the remote machine. The main script will send
# commands to the remote server through tmux's send-key command.

# Author: Pablo Piaggio (pabpia@gmail.com)

# Copyright (C) 2016 Pablo Piaggio.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

if [ $# != 1 ]; then
    echo "Usage: [ remote_IP | user@remote_IP ]"
    exit 1
fi

# get ip from parameter
if [[ $1 == *"@"* ]]; then
    user="${1%%@*}"
    ip="${1##*@}"
else
    user="$USER"
    ip="$1"
fi

userconnn="$1" # for ssh

echo "ip: $ip"
echo "remoteconn: $userconnn"

# main pane (left) will run local tests
tmux -2 new-session -s benchmarks -d "./local_tests.sh benchmarks $user $ip"

# right pane will run supporting commands on the remote machine
tmux -2 split-window -h -t benchmarks "ssh $userconnn"

tmux -2 attach-session -t benchmarks

#tmux kill-session -t benchmarks

exit 0

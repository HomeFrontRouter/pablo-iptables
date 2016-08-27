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

# print a message and exit
msg_n_exit()
{
    echo "$1 is not defined."
    echo "please set a value on the file: $SETTINGS_FILE"
    exit "$2"
}


#
# Load global settings for the test from settings file.
#
SETTINGS_FILE="./SETTINGS"  # settings file

# Load settings if file exists
if [ -f "$SETTINGS_FILE" ]; then
    source "$SETTINGS_FILE"
fi

#
# Exit if any variable is not set.
#-----------------------------------------------------------
if [ ! -n "$REMOTE_USER" ]; then
    msg_n_exit "REMOTE_USER" 1
fi
if [ ! -n "$REMOTE_IP" ]; then
    msg_n_exit "REMOTE_IP" 2
fi
if [ ! -n "$SSH_KEY" ]; then
    msg_n_exit "SSH_KEY" 3
fi
if [ ! -n "$TMUX_SESSION" ]; then
    msg_n_exit "TMUX_SESSION" 8
fi
#-----------------------------------------------------------

# main pane (left) will run local tests
tmux -2 new-session -s "$TMUX_SESSION" -d \
     "./local_tests.sh $TMUX_SESSION"

# right pane will run supporting commands on the remote machine
tmux -2 split-window -h -t "$TMUX_SESSION" "ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_IP}"

tmux -2 attach-session -t "$TMUX_SESSION"

#tmux kill-session -t benchmarks

exit 0

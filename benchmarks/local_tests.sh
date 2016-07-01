#!/bin/bash

# run_local_tests.sh

# Description: It measures maximum bandwitdth utlization for outgoing
# and incoming traffic. It coordinates with a remote machine by sending
# commands to initiate the listening/receiving service.
#
# It assumes it is being run on the first pane (0) of a tmux session. It also
# expects a remote ssh session running on the other pane (1).
#
# In this setup, it sends the command 'iperf -s' before generating local
# traffic with the command 'iper -c <remote_ip>'.
#
# It uses well-known tools like iperf, dd/netcat, and rsync to actually send
# and receive data.
#
# It receives three arguments: the name of the tmux session, the remote
# username, and the IP of the remote machine.

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

PROMPT="->"
print_msg()
{
    echo "${PROMPT} $1"
}

print_bar()
{
    echo "${PROMPT} ++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

# It only continues if it receives the tmux's session name, and the remote IP.
if [ $# != 3 ]; then
    echo "Usage: tmux_session user remote_IP"
    exit 1
fi

# check if script is inside a tmux session
if [[ ! -v TMUX ]]; then
    echo "Error: this script is not the main script."
    echo "Please run the benchmarks with 'run_tests.sh"
    exit 2
fi

# parameters
tmux_session="$1"   # session's name
remote_user="$2" # remote machine's IP
remote_machine="$3" # remote machine's IP

# Global variables
LOG="./benchmarks.log.$(date +%F.%s)" # measurements log file
SLEEP_TIME="10s"     # pause time between tests.
TRANSFER_FILE="LAS.s41e10.mp4"

# wait for a succesful remote login in the other pane
print_bar
print_msg "Please login into the remote machine in the other pane."
print_msg "When that's ready, switch to this pane (Ctrl+B then an arrow_key),"
print_msg "and press Enter."
print_bar
read

# select local NIC and address to run the test from
# (local machine may have several NICs, e.g., like a server or a router).
print_msg
print_bar
print_msg "Selecting local NIC/address (only for reporting):"

# obtain list of NICs and its IPs
links=$(ip addr show |  awk '/inet /{gsub(/\/.*/,"",$2); printf "%s (%s)\n", $2, $NF}')

OLD_IFS=${IFS}
IFS=$'\n'
# select local interface and its IP
select interface in $links; do

    # separate selected IP and device into an array
    IFS=' ' read -r -a ip_dev <<< "$interface"
    print_msg "using local IP:${ip_dev[0]} on dev:${ip_dev[1]}"
    print_bar
    # set local IP
    local_machine="${ip_dev[0]}"
    break
done
IFS=${OLD_IFS}

# exiting if no ip address was chosen
if [ -z $local_machine ]; then
    echo "Error: no interface were chosen."
    exit 3
fi

#### ping #####################################################################
print_msg
print_bar
print_msg "Test 1: ping."
print_bar
print_msg
# run 3 pings and write results to log
echo "ping from $local_machine to $remote_machine" >> "$LOG"
ping -c6 vanhalen | tee >(awk -F/ '/rtt min/{printf "%.3f\n", $5}' >> "$LOG")
echo >> "$LOG"

#### iperf over TCP ###########################################################
# request user to run remote command
print_msg
print_bar
print_msg "Test 2: upload to remote machine using iperf over TCP."
print_bar
print_msg "running 'iperf -s' on $remote_machine"
print_msg
# send command to the other pane
tmux send-keys -t "${tmux_session}.1" "iperf -s" ENTER
sleep 2s

# log title on log
echo "iperf TCP upload from $local_machine to $remote_machine" >> "$LOG"

# perform 3 tranfers
for trial in {"First","Second","Third"}; do
    print_msg "${trial} run"
    print_bar
    print_msg

    iperf -c "$remote_machine" | tee >(awk '/MBytes/{print $7, $8}' >> "$LOG")

    sleep "$SLEEP_TIME"
done
echo >> "$LOG"

# stop iperf on remote machine
sleep 2s
tmux send -t "${tmux_session}.1" C-c
sleep 2s
tmux send -t "${tmux_session}.1" ENTER

#### iperf over UDP ###########################################################
# request user to run remote command
print_msg
print_bar
print_msg "Test 3: upload to remote machine using iperf over UDP"
print_bar
print_msg
print_msg "running 'iperf -u -s' on $remote_machine"
print_msg
# send command to the other pane
tmux send-keys -t "${tmux_session}.1" "iperf -u -s" ENTER
sleep 2s

# log title on log
echo "iperf UDP upload from $local_machine to $remote_machine" >> "$LOG"

# perform 3 tranfers
for trial in {"First","Second","Third"}; do
    print_msg "${trial} run"
    print_bar
    print_msg

    iperf -u -c "$remote_machine" -b 1600M | \
        tee >(awk '/Interval/{getline; print $7, $8}' >> "$LOG")

    sleep "$SLEEP_TIME"
done
echo >> "$LOG"

# stop iperf on remote machine
tmux send -t "${tmux_session}.1" C-c
sleep 2s
tmux send -t "${tmux_session}.1" ENTER

#### dd | netcat ##############################################################
# request user to run remote command
print_msg
print_bar
print_msg "Test 4: upload to remote machine using netcat."
print_bar
print_msg

# log title on log
echo "dd/netcat upload from $local_machine to $remote_machine" >> "$LOG"

# perform 3 tranfers
for trial in {"First","Second","Third"}; do
    print_msg "${trial} run"
    print_bar
    print_msg
    print_msg "running 'nc -vvlnp 12345 >/dev/null' on $remote_machine"

    tmux send -t "${tmux_session}.1" 'nc -vvlnp 12345 >/dev/null' ENTER
    sleep 2s

    dd if="$TRANSFER_FILE" bs=1M count=1K \
        2> >(awk '/copied/{print $8, $9}' >> "$LOG") | \
        nc -vvn "$remote_machine" 12345 

    sleep "$SLEEP_TIME"
done
echo >> "$LOG"

#### rsync upload default encryption ##########################################
print_msg
print_bar
print_msg "Test 5: rsync upload with default encryption."
print_bar
print_msg

# log title on log
echo "rsync upload default cipher from $local_machine to $remote_machine" >> "$LOG"

# perform 3 tranfers
for trial in {"First","Second","Third"}; do
    print_msg "${trial} run"
    print_bar
    print_msg

    echo rsync -vP "$TRANSFER_FILE" \
        "${remote_user}@${remote_machine}":"./${TRANSFER_FILE}.$(date +%s)"

    rsync -vP "$TRANSFER_FILE" \
        "${remote_user}@${remote_machine}":"./${TRANSFER_FILE}.$(date +%s)" | \
        tee >(awk '/sent/{print $7, $8}' >> "$LOG")

    sleep "$SLEEP_TIME"
done
echo >> "$LOG"

#### rsync download default encryption ########################################
print_msg
print_bar
print_msg "Test 6: rsync download with default encryption."
print_bar
print_msg

# log title on log
echo "rsync download default cipher. $local_machine pulls from $remote_machine" >> "$LOG"

# perform 3 tranfers
for trial in {"First","Second","Third"}; do
    print_msg "${trial} run"
    print_bar
    print_msg

    echo rsync -vP "${remote_user}@${remote_machine}":"./${TRANSFER_FILE}" \
        "$TRANSFER_FILE.$(date +%s)"

    rsync -vP "${remote_user}@${remote_machine}":"./${TRANSFER_FILE}" \
        "$TRANSFER_FILE.$(date +%s)" | \
        tee >(awk '/sent/{print $7, $8}' >> "$LOG")

    sleep "$SLEEP_TIME"
done
echo >> "$LOG"

#### rsync upload ligth encryption ############################################
print_msg
print_bar
print_msg "Test 7: rsync upload with light encryption."
print_bar
print_msg

# log title on log
echo "rsync upload light cipher from $local_machine to $remote_machine" >> "$LOG"

# perform 3 tranfers
for trial in {"First","Second","Third"}; do
    print_msg "${trial} run"
    print_bar
    print_msg

    echo rsync -vP -e "ssh -c arcfour -o Compression=no" "$TRANSFER_FILE" \
        "${remote_user}@${remote_machine}":"./${TRANSFER_FILE}.$(date +%s)"

    rsync -vP -e "ssh -c arcfour -o Compression=no" "$TRANSFER_FILE" \
        "${remote_user}@${remote_machine}":"./${TRANSFER_FILE}.$(date +%s)" | \
        tee >(awk '/sent/{print $7, $8}' >> "$LOG")

    sleep "$SLEEP_TIME"
done
echo >> "$LOG"

#### rsync download ligth encryption ##########################################
print_msg
print_bar
print_msg "Test 8: rsync download with light encryption."
print_bar
print_msg

# log title on log
echo "rsync download light cipher. $local_machine pulls from $remote_machine" >> "$LOG"

# perform 3 tranfers
for trial in {"First","Second","Third"}; do
    print_msg "${trial} run"
    print_bar
    print_msg

    echo rsync -vP -e "ssh -c arcfour -o Compression=no" \
        "${remote_user}@${remote_machine}":"./${TRANSFER_FILE}" "$TRANSFER_FILE.$(date +%s)"

    rsync -vP -e "ssh -c arcfour -o Compression=no" \
        "${remote_user}@${remote_machine}":"./${TRANSFER_FILE}" "$TRANSFER_FILE.$(date +%s)" | \
        tee >(awk '/sent/{print $7, $8}' >> "$LOG")

    sleep "$SLEEP_TIME"
done
echo >> "$LOG"

#### finishing ################################################################
print_msg
print_bar
print_msg "Tests finished."
print_msg "Results are saved on log file: $LOG"
print_msg
print_msg "Press Enter to quit."
print_bar
read

# close remote session
tmux send -t "${tmux_session}.1" C-c
tmux send -t "${tmux_session}.1" C-c
sleep 2s
tmux send -t "${tmux_session}.1" ENTER
tmux send -t "${tmux_session}.1" C-d

exit 0

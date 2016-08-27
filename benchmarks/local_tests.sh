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


# If any variable is not set, ask for its value interactevely


#PROMPT="-> "
PROMPT=""
print_msg()
{
    echo "$(tput setaf 6)${PROMPT}${1}$(tput sgr 0)"
}

print_bar()
{
    echo -n "$(tput setaf 6)"
    echo -n "${PROMPT}++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "$(tput sgr 0)"
}

# It only continues if it receives the perfect parameters:
# TMUX_SESSION REMOTE_USER REMOTE_IP SSH_KEY LOG SLEEP_TIME TRANSFER_FILE NC_CMD TMUX_SESSION
if [ $# != 1 ]; then
    echo "Usage: $0 TMUX_SESSION"
    read
    exit 10
fi

# check if script is inside a tmux session
if [[ ! -v TMUX ]]; then
    echo "Error: this script is not the main script."
    echo "Please run the benchmarks with 'run_tests.sh"
    exit 11
fi

#
# Load global settings for the test from settings file.
#
SETTINGS_FILE="./SETTINGS"  # settings file

# Load settings if file exists
if [ -f "$SETTINGS_FILE" ]; then
    source "$SETTINGS_FILE"
fi

# wait for a succesful remote login in the other pane
print_msg "Please login into the remote machine in the other pane."
print_msg "When that's ready, switch to this pane (Ctrl+B then an arrow_key),"
print_msg "and press Enter."
print_bar
read

#### ping #####################################################################
if [ "$PING" == "yes" ]; then
    print_msg "PING."
    print_bar

    # run PING_COUNT pings and write results to log
    echo "ping from $LOCAL_MACHINE to $REMOTE_IP" >> "$LOG"
    ping -c"${PING_COUNT}" "$REMOTE_IP" | tee >(awk -F/ '/rtt min/{printf "%.3f\n", $5}' >> "$LOG")
    echo >> "$LOG"
    echo
fi

#### iperf over TCP ###########################################################
if [ "$IPERF_TCP" == "yes" ]; then
    print_msg "IPERF over TCP."
    print_msg "upload to remote machine using iperf over TCP."
    print_msg "running 'iperf -s' on $REMOTE_IP"
    print_bar
    # send command to the other pane
    tmux send-keys -t "${TMUX_SESSION}.1" "iperf -s" ENTER
    sleep 2s

    # log title on log
    echo "iperf TCP upload from $LOCAL_MACHINE to $REMOTE_IP" >> "$LOG"

    # perform IPERF_UDP_TRIES tranfers
    for trial in $(seq 1 "$IPERF_TCP_TRIES"); do
        print_msg "try #${trial}"

        iperf -c "$REMOTE_IP" | tee >(awk '/MBytes/{print $7, $8}' >> "$LOG")

        sleep "$SLEEP_TIME"
        echo
    done
    echo >> "$LOG"

    # stop iperf on remote machine
    sleep 2s
    tmux send -t "${TMUX_SESSION}.1" C-c
    sleep 2s
    tmux send -t "${TMUX_SESSION}.1" ENTER

    echo
fi

#### iperf over UDP ###########################################################
if [ "$IPERF_UDP" == "yes" ]; then
    print_msg "IPERF over UDP"
    print_msg "upload to remote machine using iperf over UDP"
    print_msg "running 'iperf -u -s' on $REMOTE_IP"
    print_bar
    # send command to the other pane
    tmux send-keys -t "${TMUX_SESSION}.1" "iperf -u -s" ENTER
    sleep 2s

    # log title on log
    echo "iperf UDP upload from $LOCAL_MACHINE to $REMOTE_IP" >> "$LOG"

    # perform 3 tranfers
    for trial in $(seq 1 "$IPERF_UDP_TRIES"); do
        print_msg "try #${trial}"

        iperf -u -c "$REMOTE_IP" -b "$IPERF_UDP_BANDWIDTH" | \
            tee >(awk '/Interval/{getline; print $7, $8}' >> "$LOG")

        sleep "$SLEEP_TIME"
        echo
    done
    echo >> "$LOG"

    # stop iperf on remote machine
    tmux send -t "${TMUX_SESSION}.1" C-c
    sleep 2s
    tmux send -t "${TMUX_SESSION}.1" ENTER

    echo
fi

#### dd | netcat ##############################################################
if [ "$DD_NETCAT_TCP" == "yes" ]; then
    print_msg "DD and NETCAT."
    print_msg "upload to remote machine using netcat."
    print_bar

    # log title on log
    echo "dd/netcat upload from $LOCAL_MACHINE to $REMOTE_IP" >> "$LOG"

    # perform 3 tranfers
    for trial in $(seq 1 "$DD_NETCAT_TCP_TRIES"); do
        print_msg "try #${trial}"
        print_msg "running 'nc -vvlnp 12345 >/dev/null' on $REMOTE_IP"

        tmux send -t "${TMUX_SESSION}.1" 'nc -vvlnp 12345 >/dev/null' ENTER
        sleep 2s

        dd if="$TRANSFER_FILE" bs=1M count=1K \
            2> >(awk '/copied/{print $(NF-1), $NF}' >> "$LOG") | \
            "$NC_CMD" -vvn "$REMOTE_IP" 12345

        sleep "$SLEEP_TIME"
        echo
    done
    echo >> "$LOG"

    # stop HTTP server on remote machine
    tmux send -t "${TMUX_SESSION}.1" C-c
    sleep 2s
    tmux send -t "${TMUX_SESSION}.1" ENTER

    echo
fi

# TODO: dd netcat over UDP

#### HTTP download #############################################################
if [ "$HTTP_DOWNLOAD" == "yes" ]; then
    print_msg "HTTP download."
    print_msg "running 'python -m SimpleHTTPServer 8080' on $REMOTE_IP"
    print_bar

    tmux send -t "${TMUX_SESSION}.1" 'python -m SimpleHTTPServer 8080' ENTER
    sleep 2s

    # log title on log
    echo "HTTP download from $REMOTE_IP to $LOCAL_MACHINE" >> "$LOG"

    # perform HTTP_TRIES tranfers
    for trial in $(seq 1 "$HTTP_TRIES"); do
        print_msg "try #${trial}"

        wget "http://${REMOTE_IP}:8080/${TRANSFER_FILE}" --progress=bar:force \
             -O /dev/null 2>&1 | \
             tee >(awk '/saved/{sub(/^\(/,"",$3); sub(/\)$/,"",$4);print $3,$4}' >> "$LOG")

        sleep "$SLEEP_TIME"
        echo
    done
    echo >> "$LOG"

    # stop HTTPS server on remote machine
    tmux send -t "${TMUX_SESSION}.1" C-c
    sleep 2s
    tmux send -t "${TMUX_SESSION}.1" ENTER

    echo
fi

#### HTTPS download ############################################################
if [ "$HTTPS_DOWNLOAD" == "yes" ]; then
    print_msg "HTTPS download."
    print_msg "running 'python ./https_server.py' on $REMOTE_IP"
    print_bar

    tmux send -t "${TMUX_SESSION}.1" 'python ./https_server.py' ENTER
    sleep 2s

    # log title on log
    echo "HTTPS download from $REMOTE_IP to $LOCAL_MACHINE" >> "$LOG"

    # perform HTTPS_TRIES tranfers
    for trial in $(seq 1 "$HTTPS_TRIES"); do
        print_msg "try #${trial}"

        wget "https://${REMOTE_IP}:4443/${TRANSFER_FILE}" \
             --no-check-certificate --progress=bar:force -O /dev/null 2>&1 | \
             tee >(awk '/saved/{sub(/^\(/,"",$3); sub(/\)$/,"",$4);print $3,$4}' >> "$LOG")

        sleep "$SLEEP_TIME"
        echo
    done
    echo >> "$LOG"

    echo
fi

#
# Generic rsync test
#
gen_rsync_upload()
{
    title="$1"
    subtitle="$2"
    cipher=$3
    tries="$4"

    print_msg "$title"
    print_msg "$subtitle"
    print_bar

    # log title on log
    echo "$subtitle from $LOCAL_MACHINE to $REMOTE_IP" >> "$LOG"

    # perform 3 tranfers
    for trial in $(seq 1 "$tries"); do
        print_msg "try #${trial}"

        echo rsync -e "ssh -i $SSH_KEY $cipher" -vP "$TRANSFER_FILE" \
            "${REMOTE_USER}@${REMOTE_IP}":"./${TRANSFER_FILE}.$(date +%s)"

        rsync -e "ssh -i $SSH_KEY $cipher" -vP "$TRANSFER_FILE" \
            "${REMOTE_USER}@${REMOTE_IP}":"./${TRANSFER_FILE}.$(date +%s)" | \
            tee >(awk '/sent/{print $7, $8}' >> "$LOG")

        sleep "$SLEEP_TIME"
        echo
    done
    echo >> "$LOG"
}

#### rsync upload default encryption ##########################################
if [ "$RSYNC_DEFAULT" == "yes" ]; then
    gen_rsync_upload "RSYNC TEST" "rsync upload with default ssh encryption" \
                   "" "$RSYNC_DEFAULT_TRIES"
fi

#### rsync upload ligth encryption ############################################
if [ "$RSYNC_LIGHT" == "yes" ]; then
    gen_rsync_upload "RSYNC TEST" "rsync upload with light ssh encryption" \
                   "-c arcfour -o Compression=no" "$RSYNC_LIGHT_TRIES"
fi

#
# Generic rsync download
#
gen_rsync_download()
{
    title="$1"
    subtitle="$2"
    cipher=$3
    tries="$4"

    print_msg "$title"
    print_msg "$subtitle"
    print_bar

    # log title on log
    echo "$subtitle. $LOCAL_MACHINE pulls from $REMOTE_IP" >> "$LOG"

    # perform 'tries' tranfers
    for trial in $(seq 1 "$tries"); do
        print_msg "try #${trial}"

        local_destination="$TRANSFER_FILE.$(date +%s)"

        echo rsync -e "ssh -i $SSH_KEY $cipher" -vP \
             "${REMOTE_USER}@${REMOTE_IP}":"./${TRANSFER_FILE}" \
             "$local_destination"

        rsync -e "ssh -i $SSH_KEY $cipher" -vP \
              "${REMOTE_USER}@${REMOTE_IP}":"./${TRANSFER_FILE}" \
              "$local_destination" | tee >(awk '/sent/{print $7, $8}' >> "$LOG")

        rm "$local_destination"
        sleep "$SLEEP_TIME"
        echo
    done
    echo >> "$LOG"
}

#### rsync download default encryption ##########################################
if [ "$RSYNC_DEFAULT" == "yes" ]; then
    gen_rsync_download "RSYNC TEST" "rsync download with default ssh-encryption" \
                       "" "$RSYNC_DEFAULT_TRIES"
fi

#### rsync download ligth encryption ############################################
if [ "$RSYNC_LIGHT" == "yes" ]; then
    gen_rsync_download "RSYNC TEST" "rsync download with light ssh-encryption" \
                       "-c arcfour -o Compression=no" "$RSYNC_LIGHT_TRIES"
fi


#### finishing ################################################################
print_msg "Tests finished."
print_msg "Results are saved on: $LOG"
print_msg
print_msg "Press Enter to quit."
print_bar
read

# close remote session
tmux send -t "${TMUX_SESSION}.1" C-c
tmux send -t "${TMUX_SESSION}.1" C-c
sleep 2s
tmux send -t "${TMUX_SESSION}.1" ENTER
tmux send -t "${TMUX_SESSION}.1" C-d

exit 0

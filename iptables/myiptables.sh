#!/bin/bash

# Iptables rules for home security.
# Author: Pablo Piaggio.
# Date: Wed Oct 24 15:39:21 CDT 2012
# Version 1.0

# Flush all current rules from iptables.
iptables -F

# Accept packets belonging to established and related connections.
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Set access for localhost
iptables -A INPUT -i lo -j ACCEPT

# Allow SSH connections on tcp port 22
# This is essential when working on remote servers via SSH to prevent locking
# yourself out of the system
iptables -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport 2312 -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport 80 -j ACCEPT

# Set default policies for INPUT, FORWARD and OUTPUT chains
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
#
# List rules
#
iptables -L -v

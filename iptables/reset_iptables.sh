#!/bin/bash

# Iptables rules for home security.
# Author: Pablo Piaggio.
# Date: Wed Oct 24 15:39:21 CDT 2012
# Version 1.0

# Accept all connections on all chains.
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT

# Flush all rules.
iptables -F

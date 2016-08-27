#!/bin/bash

printo()
{
    error="$1"
    key="$2"

    echo 'if [ ! -n "$'"$key"'" ]; then'
    echo '    msg_n_exit "'"$key"'" '"$error"
    echo 'fi'
}

export -f printo

grep -vE '\#|^$' SETTINGS | \
    awk -F= '{print $1}' | cat -n | xargs -n 2 bash -c 'printo "$1" "$2"' _

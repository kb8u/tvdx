#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

VENDOR="1d6b"
PRODUCT="0002"

for DIR in $(find /sys/bus/usb/devices/ -maxdepth 1 -type l); do
  if [[ -f $DIR/idVendor && -f $DIR/idProduct &&
        $(cat $DIR/idVendor) == $VENDOR && $(cat $DIR/idProduct) == $PRODUCT ]]; then
    echo 0 > $DIR/authorized
    sleep 0.5
    echo 1 > $DIR/authorized
  fi
done


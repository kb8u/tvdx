#!/bin/bash

# timeout runs a program for n seconds
# rtl_fm tunes to frequency from command line, output in format for rds decoder
# redsea is rds decoder, output is json format
# jq is json pretty print plus filter
/usr/bin/timeout 2 \
  rtl_fm -M fm -l 0 -A std -p 0 -s 171k -g 40.2 -F 9 -f $1M 2>/dev/null \
  | /usr/local/bin/redsea \
  | jq --monochrome-output '.pi'

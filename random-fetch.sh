#!/bin/bash

LOGO_DIR="$HOME/Pictures/term-logos"
RANDOM_LOGO=$(find "$LOGO_DIR" -type f -iname "*.png" | shuf -n 1)

WINDOWS_COUNT=$(pgrep -cx kitty)

TERM_WIDTH=$(tput cols)

LOGO_WIDTH=$(( TERM_WIDTH / 4 ))
MIN_WIDTH=10
MAX_WIDTH=18

if (( LOGO_WIDTH < MIN_WIDTH )); then
  LOGO_WIDTH=$MIN_WIDTH
elif (( LOGO_WIDTH > MAX_WIDTH )); then
  LOGO_WIDTH=$MAX_WIDTH
fi

if (( WINDOWS_COUNT == 1 )); then
  # One window: show everything
  fastfetch --logo-type kitty --logo "$RANDOM_LOGO" --logo-width $LOGO_WIDTH
else
  # Multiple windows: show nothing
  :
fi


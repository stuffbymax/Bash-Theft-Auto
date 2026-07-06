#!/bin/bash

# --- Animation Frames ---
frames=(
  "
     _,-._
    / \_/ \
    >-(_)-<
    \_/ \_/
      `-'
  "
  "
     _,-._
    / \_/ \
   >-(_)-<
    \_/ \_/
      `-'
  "
  "
     _,-._
    / \_/ \
   >-(_)-<
    \_/ \_/
      `-'
  "
  "
     _,-._
    / \_/ \
    >-(_)-<
    \_/ \_/
      `-'
  "
)

# --- Animation Speed ---
delay=0.1 # Seconds between frames

# --- Function to Display Animation ---
animate() {
  local frame_count=${#frames[@]}
  local i=0

  while true; do
    clear
    echo "${frames[$i]}"
    sleep "$delay"
    ((i = (i + 1) % frame_count)) # Cycle through frames
  done
}

# --- Main Script ---

# Check for Ctrl+C (SIGINT) and exit cleanly
trap "clear; exit 0" SIGINT

animate & # Run animation in the background
pid=$!   # Get process ID of the animation

# Simulate other parts of your script here:
sleep 5  # Animation runs for 5 seconds

# --- Stop Animation and Exit ---
kill "$pid"  # Stop the animation process
wait "$pid"  # Wait for the animation process to finish
clear
echo "Animation stopped."
exit 0

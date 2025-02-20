#!/bin/bash

# --- Animation Plugin ---

# Helper animation for drug transactions
drug_transaction_animation() {
  local delay=0.1
  local bag="[ ]"
  local money="$"
  local transaction_length=7

  for i in $(seq 1 "$transaction_length"); do
    clear
    echo "Processing Transaction..."
    if (( i % 2 == 0 )); then
      echo "  $bag   $money"  # Bag then Money
    else
      echo "  $money   $bag"  # Money then Bag
    fi
    sleep "$delay"
  done
}

# Initial game menu
loading_animation() {
	clear_screen

    # Added animation
	local delay=0.2
	local GTA="GTA"
	local gta_char="-"
	local gta_length=10

	for i in $(seq 1 "$gta_length"); do
		clear_screen
		echo "Loading Screen"
		space=$(printf "%${i}s" "$gta_char")

		echo "$space $GTA"
		sleep "$delay"
	done
}

# Function for traveling to a new location
air_travel_animation() {
    local delay=0.05 # Made it go faster, since the path is longer
    local path_length=150 #Significantly increased!
    local airplane=">--"
    local sky="                                                  "
    local altitude=0
    local cloud1="    _,-._"
    local cloud2="   / \_/ \ "
    local cloud3="   >-(_)-<"
    local cloud4="  /_/ \_/"


    for i in $(seq 1 "$path_length"); do
        clear
        space=$(printf "%${i}s" "")
        altitude=$((i / 4)) # Simulate altitude gain
        sky_space=$(printf "%${altitude}s" "")

        echo "$sky_space$cloud1"
        echo "$sky_space$cloud2"
        echo "$sky_space$cloud3"
        echo "$sky_space$cloud4"
        echo "$sky_space$space$airplane"
        echo "$sky"
        echo "$sky"
        echo "Flying..."
        sleep "$delay"
    done
}

# Buying Animation
buy_animation() {
	local delay=0.05
	local items="[ ] [ ] [ ] [ ] [ ]"
	for i in $(seq 1 5); do
		clear
		echo "Buying..."
		itemSpace=$(printf "%${i}s" " ")
		echo "$itemSpace$items"
		sleep "$delay"
	done
	clear
	echo "BOUGHT"
	sleep 1
}

# Working Animation
working_animation() {
  local delay=0.08
  local work_char="[=]"
  local progress_bar_length=30
  echo "Working..."

  for i in $(seq 1 "$progress_bar_length"); do
      clear
      echo "Working..."
      progress=$(printf "%${i}s" "$work_char")
      remaining=$((progress_bar_length - i))
      empty=$(printf "%${remaining}s" " ")
      echo "[$progress$empty]"
      sleep "$delay"
  done
}

# Robbing Animation
robbing_animation() {
  local delay=0.1
  local vault="[=======]"
  local robber=" 0 "
  local cops=" P "
  local robbing_length=15 # Shorter than work, more hectic!

  for i in $(seq 1 "$robbing_length"); do
      clear
      echo "Robbing the store..."
      space1=$(printf "%${i}s" " ")  # Robber moving towards vault
      space2=$(printf "%$((robbing_length - i))s" " ") # Cops chasing

      echo "  $vault"
      echo "$space1$robber$space2$cops"  # Robber vault, cops at end

      sleep "$delay"
  done
  sleep 1
}

# Hospital Animation
hospital_animation() {
  local delay=0.2
  local heart="<3"
  local empty="   "
  local hospital_length=10

  for i in $(seq 1 "$hospital_length"); do
      clear
      echo "Treating wounds..."
      if (( i % 2 == 0 )); then  # Alternate heart
        heart="   "
        empty="<3"
      else
         heart="<3"
         empty="   "
      fi
      echo "  $heart $empty"
      sleep "$delay"
  done
}

# Hooking Animation
hooking_animation() {
  local delay=0.15
  local heart="<3"
  local dollar="$"
  local hooker_length=8  # Relatively short for the action

  for i in $(seq 1 "$hooker_length"); do
    clear
    echo "Hiring..."
    if (( i % 2 == 0 )); then
      echo "  $heart   $dollar" # Heart, Dollar
    else
      echo "  $dollar   $heart" # Dollar, Heart
    fi

    sleep "$delay"
  done
}

# Gang War Animation
gang_war_animation() {
  local delay=0.1
  local gang1="G1"  # Simpler labels
  local gang2="G2"
  local war_length=12

  for i in $(seq 1 "$war_length"); do
      clear
      echo "Gang War in Progress..."
      if (( i % 2 == 0 )); then  # Alternate
        space=$(printf "%$((i * 2))s" " ")
        echo "$space$gang1 $gang2" # Gangs at oppisite ends
      else
        space=$(printf "%$((i * 2))s" " ")
         echo "$gang2 $space$gang1"
      fi
      sleep "$delay"
  done
}

# Carjacking Animation
carjacking_animation() {
  local delay=0.12
  local car="[C]"
  local person="P"
  local jack_length=10

  for i in $(seq 1 "$jack_length"); do
    clear
    echo "Carjacking Attempt..."
    space=$(printf "%${i}s" " ")

    echo "$space$person $car"

    sleep "$delay"
  done
}

# Heist Animation
heist_animation() {
  local delay=0.1
  local safe="[S]"
  local robber="R"
  local guards="G"
  local heist_length=10

  for i in $(seq 1 "$heist_length"); do
    clear
    echo "Planning The Heist"
    space=$(printf "%${i}s" " ")
    echo "     $safe"
    echo "$space $robber       $guards"
    sleep "$delay"
  done
}

# Music Playing Animation
music_playing_animation() {
  local delay=0.2
  local music_char="♫"
  local music_length=10

  for i in $(seq 1 "$music_length"); do
    clear
    echo "Now Playing!"
    space=$(printf "%${i}s" " ")
    echo "$space$music_char"
    sleep "$delay"
  done
}

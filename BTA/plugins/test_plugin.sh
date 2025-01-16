#!/bin/bash

play_music() {
    # Path to the music file
    music_file="./music/the_loading_screen.mp3"
    # Check if the music file exists
    if [[ -f $music_file ]]; then
        # Play the music file in the background
        mpg123 -q "$music_file" &
        music_pid=$!
    else
        echo "Music file not found: $music_file"
    fi
}

stop_music() {
    if [[ -n $music_pid ]]; then
        kill $music_pid
    fi
}

# Function to display a simple loading animation
loading_animation() {
    local -r delay='0.1'
    local spinstr='|/-\'
    local temp

    while true; do
        for i in {0..3}; do
            temp="${spinstr:i:1}"
            echo -ne "$temp" "\r"
            sleep $delay
        done
    done
}

# Function to stop the animation after a given time
stop_animation() {
    sleep 5  # Duration to show the animation
    kill "$1"
}

# Main script
play_music
echo "this is a test plugin that does Starting loading animation..."
loading_animation &  # Start the animation in the background
ANIMATION_PID=$!

stop_animation $ANIMATION_PID  # Stop the animation after a set duration
wait $ANIMATION_PID 2>/dev/null

stop_music  # Stop the music after the loading is complete

echo -e "\Loading complete!"




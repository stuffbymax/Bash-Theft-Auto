play_music() {
    # Path to the music file
    music_file="./music/the_loading_screen.mp3"    # Check if the music file exists
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

# Function to play music
play_music() {
  local music_files=(
    "music/platforma.mp3"
    "music/the_loading_screen.mp3"
    "music/doom.mp3"
  )
  
    while true; do
        clear_screen
        echo "Choose a song to play:"
        for i in "${!music_files[@]}"; do
            echo "$((i + 1)). $(basename "${music_files[$i]}")"
        done
       echo "press q to Stop Music"
       echo "$(( ${#music_files[@]} + 1 )). Back to Main menu"
        read -r music_choice
        if ! [[ "$music_choice" =~ ^[0-9]+$ ]]; then
            echo "Invalid input. Please enter a number from the menu."
             read -p "Press Enter to continue..."
            continue # Go back to music player menu
        fi

        if (( music_choice <= ${#music_files[@]} )); then
            local selected_track="${music_files[$((music_choice - 1))]}"
            if [[ -f "$selected_track" ]]; then
              echo "Playing: $(basename "$selected_track")"
              mpg123 -q "$selected_track" # Run in foreground
            else
                echo "Error: Music file '$selected_track' not found."
                read -p "Press Enter to continue..."

            fi

        elif (( music_choice == ${#music_files[@]} + 1 )); then
             pkill mpg123
            clear_screen
             break  # Exit the music player menu
         else
            echo "Invalid choice."
             read -p "Press Enter to continue..."
        fi
        
    done
}

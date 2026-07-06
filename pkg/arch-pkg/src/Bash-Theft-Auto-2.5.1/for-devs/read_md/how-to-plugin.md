# Bash Script Plugins: A Guide

This document explains how the provided bash script uses plugins, how to create them, and the benefits of this approach.

## How Plugins Work in This Script

The script uses a simple yet effective method for loading plugins:

1.  **Plugin Directory:** It defines a variable `plugin_dir="plugins"` which sets the name of the folder where the plugins will be located. All plugin files will reside in this folder, named "plugins."

2.  **File Discovery:**  It uses the `find` command to search for `.sh` files within the `plugins` directory:
    ```bash
    find "$plugin_dir" -maxdepth 1 -name "*.sh" -print0
    ```
    -   `-maxdepth 1`: Limits the search to only the immediate files within the folder, not any subfolders.
    -   `-name "*.sh"`: Finds all files ending in `.sh`.
    -   `-print0`:  Handles filenames with spaces correctly.
   
3.  **Sourcing:** The core of loading plugins is the `source` command:
    ```bash
     source "$plugin"
    ```
     -   `source` (also written as `.`) executes the contents of the plugin file within the *current shell environment*.  This is crucial because any functions, variables, etc. defined within the plugin will be directly available to the main script.

## How to Create a Plugin

1.  **Locate the `plugins` directory:** If it doesn't exist, create a folder named `plugins` in the same directory as your main script.

2.  **Create Plugin Files:** Inside the `plugins` directory, create one or more `.sh` files. Each file represents a plugin. Use a descriptive name for each (e.g., `plugin_loading_animation.sh`, `plugin_location_info.sh`).

3.  **Write Plugin Code:** In your `.sh` plugin files, you can define:
    *   **Functions:**  Add new functions (like `start_loading_animation` from the script).
    *   **Variables:** While possible, it's generally better to define variables in the main script and keep plugins for functions.
    *   **Aliases:** Add aliases, but be cautious about naming conflicts.
    *   **Anything valid in bash:** Use normal bash commands. However, functions are the best practice for modularity and reusability.

4.  **Make it executable:** While not required, it's good practice to make the plugin files executable by using `chmod +x <plugin_name>.sh` . This allows you to execute them separately for testing.

## Example Plugin: `plugin_loading_animation.sh`

Here's an example plugin that adds a loading animation and location info:

```bash
#!/bin/bash

start_loading_animation() {
  local i
  local animation_chars="-\|/"
  for i in $(seq 1 20); do
    printf "\rLoading %s" "${animation_chars:$(($i % ${#animation_chars})):1}"
    sleep 0.1
  done
    echo
}

show_location_info() {
  local location="$1"

  case "$location" in
    "Los Santos")
        echo "Welcome to Los Santos, the city of dreams and chaos."
        echo "You can find high end vehicles, cheap drugs, and dangerous gang activity here."
        ;;
    "San Fierro")
        echo "Welcome to San Fierro, a city built on hills, known for its bridges and tech culture."
        echo "You can find great mechanic jobs, good street races, and a good amount of crime here."
        ;;
      "Las Venturas")
        echo "Welcome to Las Venturas, the gambling capital of the world."
          echo "You can find casinos and heists here, as well as a good amount of jobs in hotels and resorts."
        ;;
      "Vice City")
        echo "Welcome to Vice City, the land of sunshine, beaches, and 80s style crime."
        echo "You can find hookers and drug deals here, as well as a good amount of jobs in the docks."
        ;;
      "Liberty City")
        echo "Welcome to Liberty City, a city with a dark atmosphere, known for its corruption and crime."
         echo "You can find the most dangerous jobs here, as well as the most lucrative ones. Be careful."
         ;;
     *)
        echo "You are in an unknown location."
        ;;
  esac
   sleep 3
}
```

**How to Use the Example Plugin**

1.  **Save the Plugin:** Save the code above as `plugin_loading_animation.sh` inside the `plugins` directory.

2.  **Run the Script:**  Execute the main bash script.

**Explanation of Example Plugin**

*   **`start_loading_animation()`:** This function displays a basic loading animation using a loop.
*  **`show_location_info()`:** This function displays different information about the location the player is on, depending on the input.
*   **Sourcing:** The main script loads this plugin, making the defined functions available in the main script's scope. The `start_loading_animation` is called at the start of the script, and `show_location_info` is called every time the player travels to a new location.

## Benefits of Plugins

*   **Modularity:** Break your code into reusable and maintainable components.
*   **Organization:** The main script becomes cleaner by delegating features to plugin files.
*   **Reusability:** The loading process is consistent.
*   **Extensibility:** Easily add new features without modifying the core script.
*   **Separation of Concerns:**  The main script focuses on the game logic, while plugins provide enhancements and additional functionalities.
*   **Collaboration:** Plugins can be easily shared and combined.

## Important Considerations

*   **Naming Conventions:** Use descriptive names for plugin files and the functions within them.
*   **Avoid Globals in Plugins (Generally):**  It's best practice to define global variables in the main script. Plugins should primarily provide functions to avoid name conflicts and make debugging easier.
*   **Dependencies:** Keep plugins self-contained whenever possible. Avoid too many dependencies between plugins.
*   **Error Handling:** If a plugin fails to load or has errors, it might cause issues to the script. Test your plugins carefully to avoid errors.

## Next Steps

1.  **Try it Out:** Create the `plugins` folder, save the example plugin, and then run the script.
2.  **More Plugins:** Create new plugins for features such as special abilities, cheat codes, random events, different character customizations, etc.
3.  **Advanced Plugin Management:** For larger projects, consider adding logic to load or disable plugins based on configuration files.


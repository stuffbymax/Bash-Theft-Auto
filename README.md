# Bash Theft Auto

## developent status **halted**

## licensing

- [The code and animation is under MIT](./LICENSE)
- [The music and SFX is under CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- The ASCII animation is AI-generated.

## Overview made by **AI**

Bash Theft Auto is a text-based adventure game implemented entirely in Bash. Inspired by classic open-world crime games, this script allows players to navigate a virtual world, earn money through legitimate jobs or criminal activities, purchase weapons and items, engage in dangerous encounters, and manage their health and inventory. 

The game features several locations, a variety of jobs and crimes, drug dealing, and even a music player. The script also includes save and load functionality, so players can continue their progress at a later time.

## Features

-   **Multiple Locations**: Explore different cities like Los Santos, San Fierro, Las Venturas, Vice City, and Liberty City.
-   **Player Customization**: Start the game by entering your player's name.
-   **Dynamic Economy**: Earn cash through various jobs with different payouts based on location and job type.
-   **Criminal Activities**: Engage in heists, gang wars, store robberies, and carjacking with risks and rewards.
-   **Inventory Management**: Purchase and manage an inventory of guns, drugs, and other items.
-   **Health System**: Manage your health, and visit the hospital for treatment.
-   **Drug Dealing**: Buy and sell drugs with risk and rewards.
-   **Hospital Services**: Get treatment, buy health packs, and body armor.
-   **Hookers**: Hire hookers to restore some health.
-   **Music Player**: Play music within the game.
-   **Save/Load**: Persist and load game progress.
-   **Plugin Support**: Extend the game's functionality by adding custom plugins.

## Getting Started

### Prerequisites

-   A Unix-like operating system (e.g., Linux, macOS) with `bash` installed.
-   `mpg123` installed (for the music player).
    -   On Debian/Ubuntu: `sudo apt-get install mpg123`
    -   On macOS: `brew install mpg123`

### Installation

1.  **Download the Script:** Save the `bash` script to your local machine (e.g., `bash_theft_auto.sh`).
2.  **Make the Script Executable:**

    ```bash
    chmod +x bash_theft_auto.sh
    ```
    
4.  **IF DELITED Create Necessary Directories:**
   
	- Create a `plugins` directory for your plugins
	- Create a `music` directory for your music files (must be .mp3 files)
	- Create a `saves` directory for your save files

    ```bash
    mkdir plugins
	mkdir music
	mkdir saves
    ```

5.  **Add music files** Put .mp3 files into the music folder. The game will randomly choose between the files in the folder.

### How to Play

1.  **Run the Script:**
    ```bash
    ./bta.sh
    ```
2.  **Follow the Prompts:** The game will guide you through the different actions and options available.
3.  **Navigate Using Numbers:** Use the number keys on your keyboard to select options in the game menu.
4.  **Use "Enter" to Continue:** Press `Enter` to proceed after each action or message.

## Game Mechanics

### Main Menu

The main menu presents the following options:

-   **Travel to another city**: Move your character to a new city for a cost.
-   **Buy guns**: Purchase weapons from the gun store.
-   **Show inventory**: View your current inventory of items, cash, health, drugs and weapons.
-   **Work (earn money)**: Take on a legitimate job, such as taxi driving, delivery, mechanic work, security, or street performing to earn cash.
-   **Work (criminal activity)**: Participate in dangerous activities such as a heist, gang war or carjacking to gain money and potentially take damage.
-   **Buy drugs**: Buy different types of drugs from a dealer.
-   **Sell drugs**: Sell your drugs for a profit.
-   **Hire hooker**: Hire a hooker to restore health.
-   **Visit hospital**: Get full treatment or buy a health pack or body armor to reduce damage on the next encounter.
-   **Exit Game**: Quit the game.
-   **Save Game**: Save your current progress.
-   **Load Game**: Load a previously saved game.
-   **Play Music**: Play music in the game.

### Jobs and Criminal Activities

-   Different jobs offer varying pay based on location.
-   Criminal activities have risk involved - if you succeed you might gain money, but if you fail you might lose money or health.
-   Body armor can reduce damage by 50% in the next encounter you take damage.

### Inventory

-   Keep track of your cash, health, guns, and other items.
-   Purchase different guns at the gun store.
-   Drugs can be bought and sold at the drug dealer.

### Health System

-   Health points affect how long you can play the game - if you reach 0 health you are transported to a hospital where you are healed for $200.
-   Use health packs or a hooker to restore health.
-   Visit the hospital to receive treatment for your wounds.

### Save and Load

-   The game saves your character's name, location, cash, health, inventory, and drug information in separate files within the `saves` directory.
-   You can load a previous game using the "Load Game" option in the main menu.

### Music Player

-   Choose and play music files in the `music` directory.
-   Use "q" to stop the music.

## Plugin Support

The game supports plugins, which are simply `.sh` files located in the `plugins` folder. To extend the game’s functionalities you can create your own plugin files.

### Plugin guidelines

- Plugin files must have the `.sh` extension.
- Plugin files must be placed into the `plugins` directory.
-  The plugin files are sourced on game startup.
- Your plugin script can add new functions that you can use in the main game loop, for example:
	- New work function.
	- New criminal activity function.
	- New weapons or items
	- New locations
	
### Contributing

If you wish to contribute to this project, feel free to fork the repository and submit a pull request with your improvements.

This project is open-source. Feel free to use and modify the code for any purpose.

### Disclaimer

This game is a text-based simulation and does not condone real-life criminal activity.
Rockstar Games has no involvement with this project, and the content within this game is not associated with or endorsed by them in any way.

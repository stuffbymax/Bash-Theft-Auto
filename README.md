# Bash Theft Auto

## Overview made by **AI** outdated tho

> **A GTA-inspired open-world crime game — running entirely in your terminal.**

**Bash Theft Auto (BTA)** is a text-based open-world game written in **Bash**. Explore different cities, make money, buy weapons, take on jobs, commit crimes, manage your health and inventory, and build your criminal empire — all from the command line.

[![Bash](https://img.shields.io/badge/Made%20with-Bash-4EAA25?logo=gnubash\&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/Code-MIT-blue.svg)](LICENSE)
[![GitHub](https://img.shields.io/github/stars/stuffbymax/Bash-Theft-Auto?style=flat\&logo=github)](https://github.com/stuffbymax/Bash-Theft-Auto)

---

## Features

* **Multiple cities** — Travel between locations inspired by the GTA universe.
* **Dynamic economy** — Earn money through jobs and criminal activities.
* **Weapons & inventory** — Buy and manage weapons and other items.
* **Jobs** — Make legitimate money through different types of work.
* **Criminal activities** — Take part in heists, gang wars, robberies, carjackings and more.
* **Drug dealing** — Buy and sell drugs for profit.
* **Health system** — Take damage, heal yourself and visit the hospital.
* **Body armour** — Reduce damage during dangerous encounters.
* **Save & load** — Save your progress and continue later.
* **Music player** — Play music directly from the game.
* **Plugin system** — Extend the game with your own Bash plugins.
* **Multiple languages** — Language support is included in the project.
* **Terminal-native** — No GUI required.

---

## Installation

### Requirements

Bash Theft Auto runs on Unix-like systems with Bash.

You will need:

* **Bash**
* A terminal
* `mpg123` if you want to use the music player

### Arch Linux

On Arch Linux, install the required package with:

```bash
sudo pacman -S mpg123
```

### Debian / Ubuntu

```bash
sudo apt install mpg123
```

### macOS

```bash
brew install mpg123
```

---

## Getting Started

Clone the repository:

```bash
git clone https://github.com/stuffbymax/Bash-Theft-Auto.git
cd Bash-Theft-Auto
```

Make the game executable:

```bash
chmod +x bta.sh
```

Start the game:

```bash
./bta.sh
```

Follow the instructions shown in the terminal.

Most menus use **number keys** to select an option, and **Enter** is used to continue.

---

## How to Play

After starting the game, you'll be able to perform different actions from the main menu.

### Travel

Travel between different cities.

Travelling costs money, so make sure you have enough cash before heading across the map.

### Work

Take legitimate jobs to earn money.

Depending on the version of the game and your location, available jobs can include things such as:

* Taxi driving
* Delivery
* Mechanic work
* Security
* Street performing

### Weapons

Visit the gun store to purchase weapons.

Your weapons can help you survive dangerous encounters and criminal activities.

### Criminal Activities

If legitimate work isn't making you rich fast enough, you can take greater risks.

Possible activities include:

* Heists
* Gang wars
* Store robberies
* Carjackings

Criminal activities can provide larger rewards, but failure can cost you money or health.

### Drugs

Buy drugs from dealers and sell them for a potential profit.

Prices and opportunities can vary, so choose when and where you trade carefully.

### Health

Keep an eye on your health.

You can use hospital services and health items to recover. If your health reaches zero, you'll be sent to hospital and charged for treatment.

Body armour can also reduce damage during encounters.

---

## Saving Your Game

Bash Theft Auto includes a save system so you can keep your progress.

Your save data can contain information such as:

* Player name
* Current location
* Cash
* Health
* Weapons
* Inventory
* Drug information

Use the **Save Game** and **Load Game** options from inside the game.

---

## Music

Bash Theft Auto includes a built-in music player.

Place compatible `.mp3` files in the `music` directory and the game can play them.

You can use:

```text
q
```

to stop the currently playing music.

> Music and sound effects are separately licensed from the game's source code. See the licensing section below.

---

## Plugins

Bash Theft Auto supports plugins written in Bash.

Plugins are stored in:

```text
plugins/
```

Plugin files should use the `.sh` extension.

For example:

```text
plugins/
├── example.sh
├── my-plugin.sh
└── another-plugin.sh
```

Plugins are sourced when the game starts, allowing them to extend the game with things such as:

* New jobs
* New criminal activities
* New weapons
* New items
* New locations
* Other custom functionality

If you're interested in developing plugins, check the development-related files in the repository.

---

## Project Structure

Some of the important directories and files include:

```text
Bash-Theft-Auto/
├── bta.sh              # Main game
├── bta-beta.sh         # Beta version
├── plugins/            # Game plugins
├── music/              # Music files
├── sfx/                # Sound effects
├── floppy/             # Floppy-related resources
├── pkg/                # Packaging resources
├── install-languages/  # Language installation resources
├── for-devs/           # Developer resources
├── BTA-archive/        # Archived project files
├── how-to-install.md   # Additional installation information
├── todo.md             # Project TODO list
├── ver_checker.sh      # Version checker
├── version.txt         # Current version
└── LICENSE             # MIT license
```

---

## Development

Bash Theft Auto is intentionally written in **Bash**.

If you want to experiment with the project, you can clone the repository and modify the scripts directly:

```bash
git clone https://github.com/stuffbymax/Bash-Theft-Auto.git
cd Bash-Theft-Auto
```

For development, it's recommended to test changes from a clean clone and avoid committing generated save files or personal music.

---

## Contributing

Contributions are welcome!

You can contribute by:

1. Forking the repository.
2. Creating a branch for your changes.
3. Making your changes.
4. Testing them in Bash.
5. Opening a pull request.

Bug reports, ideas, plugins and improvements are also welcome.

If you find a bug, please open an issue and include:

* Your operating system
* Bash version
* What you were doing
* What happened
* Any relevant terminal output

---

## Disclaimer

**Bash Theft Auto is a fictional video game.**

The criminal activities represented in the game are fictional gameplay mechanics and are **not intended to encourage real-world criminal activity**.

Bash Theft Auto is a fan-made project and is **not affiliated with, sponsored by, or endorsed by Rockstar Games**.

The project uses references and names inspired by the Grand Theft Auto universe, but the game itself is an independently developed Bash project.

---

## Licensing

### Code

The game's code and animations are licensed under the **MIT License**.

See [`LICENSE`](LICENSE) for the full license.

### Music

The project's music is licensed under the **Creative Commons Attribution 4.0 International License (CC BY 4.0)**.

Music and sound effects are credited to:

**stuffbymax / Martin Petik**

See the relevant project files for attribution and individual asset licensing information.

Some sound effects are third-party assets and may have their own licenses. Check the [`sfx/`](sfx/) directory and associated information before redistributing individual assets.

- [The code and animation is under MIT](./LICENSE)
- [The music and SFX is under CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- The ASCII animation is AI-generated. because i suck at art

---

## Support the Project

If you enjoy Bash Theft Auto, consider giving the repository a ⭐ on GitHub!

**Repository:**
https://github.com/stuffbymax/Bash-Theft-Auto

---

## Have Fun

```text
██████╗  █████╗ ███████╗██╗  ██╗    ████████╗██╗  ██╗███████╗███████╗████████╗     █████╗ ██╗   ██╗████████╗ ██████╗ 
██╔══██╗██╔══██╗██╔════╝██║  ██║    ╚══██╔══╝██║  ██║██╔════╝██╔════╝╚══██╔══╝    ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗
██████╔╝███████║███████╗███████║       ██║   ███████║█████╗  █████╗     ██║       ███████║██║   ██║   ██║   ██║   ██║
██╔══██╗██╔══██║╚════██║██╔══██║       ██║   ██╔══██║██╔══╝  ██╔══╝     ██║       ██╔══██║██║   ██║   ██║   ██║   ██║
██████╔╝██║  ██║███████║██║  ██║       ██║   ██║  ██║███████╗██║        ██║       ██║  ██║╚██████╔╝   ██║   ╚██████╔╝
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝       ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝        ╚═╝       ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ 
                                                                                                                     
        BASH THEFT AUTO

   The terminal is your city.
```

**Start the game:**

```bash
./bta.sh
```

# Bash Theft Auto

**Bash Theft Auto (BTA)** is a terminal-based open-world crime game written
entirely in Bash. Explore cities, earn money, buy equipment, build businesses,
take on missions, and grow your criminal empire from the command line.

**Current release:** `v2.6.0`

[![Bash](https://img.shields.io/badge/Made%20with-Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/Code-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/stuffbymax/Bash-Theft-Auto?style=flat&logo=github)](https://github.com/stuffbymax/Bash-Theft-Auto)

> This is a fictional game. Its criminal activities are gameplay mechanics and
> are not intended to encourage real-world crime. Bash Theft Auto is not
> affiliated with or endorsed by Rockstar Games.

## Features

- Travel between multiple cities with different risks and opportunities.
- Earn money through legitimate jobs, crimes, missions, and businesses.
- Buy weapons, ammunition, items, vehicles, properties, and upgrades.
- Manage health, body armour, wanted level, respect, city reputation, and gangs.
- Take part in robberies, heists, gang wars, police encounters, and drive-by
  missions.
- Trade drugs, run protection rackets, and manage passive business income.
- Use the bank, loans, black-market auctions, fences, and safe houses.
- Recruit allies, unlock contacts and perks, and train at the gym.
- Complete timed contact missions and work toward the Kingpin end game.
- Save and load your progress.
- Play music and sound effects through `mpg123`.
- Extend the game with Bash plugins.

## Requirements

- A Unix-like operating system
- Bash 4 or newer
- `mpg123` for music and sound effects (optional, but recommended)
- `git` to clone the repository

Windows, BSD, and macOS are not officially supported. The game may work in
some compatibility environments, but they are not tested or supported by the
project.

### Install the audio dependency

Debian or Ubuntu:

```bash
sudo apt install mpg123
```

Arch Linux:

```bash
sudo pacman -S mpg123
```

macOS with Homebrew:

```bash
brew install mpg123
```

If `mpg123` is not installed, the game still runs, but audio playback is
disabled.

## Installation and first run

Clone the repository and start the main release:

```bash
git clone https://github.com/stuffbymax/Bash-Theft-Auto.git
cd Bash-Theft-Auto
chmod +x bta.sh
./bta.sh
```

The script uses paths relative to its own directory, so it can be launched
from the repository root or by providing its path:

```bash
/path/to/Bash-Theft-Auto/bta.sh
```

Use the numbered menu options shown in the terminal. Press **Enter** when the
game asks you to continue.

## Saving and loading

Use the save and load options in the game menu. Save files are created in a
local `saves/` directory the first time you save. They include player
progress, inventory, weapons and ammunition, businesses, territory, contacts,
perks, and other game state.

The `saves/` directory is local player data and should not be committed to
the repository. To start over, use the in-game delete-save option rather than
editing individual save files.

## Audio

Music tracks are stored in [`music/`](music/) and sound effects are stored in
[`sfx/`](sfx/). The built-in music player can play `.mp3` files from the
music directory. Press `q` to stop the currently playing track.

Audio assets have licensing and attribution requirements separate from the
game code. See [`music/LICENSE.md`](music/LICENSE.md),
[`sfx/LICENSE`](sfx/LICENSE), and [`sfx/Creators.md`](sfx/Creators.md) before
redistributing them.

## Debugging

The main script supports an optional debug log. Enable it with either form:

```bash
BTA_DEBUG=1 ./bta.sh
./bta.sh --debug
```

Debug output is appended to `bta_debug.log` in the project directory. Do not
commit this log or other local runtime files.

To compare the checked-out version with the latest version on GitHub:

```bash
chmod +x ver_checker.sh
./ver_checker.sh
```

## Plugins

Plugins are Bash files placed directly in [`plugins/`](plugins/). The game
loads `.sh` files from that directory when it starts.

To add a plugin:

1. Create a file such as `plugins/my-plugin.sh`.
2. Define functions or hooks without overwriting existing game functions.
3. Start the game and test the plugin.

The repository includes examples for animation, bounty contracts, the stock
market, and plugin testing. See
[`for-devs/read_md/how-to-plugin.md`](for-devs/read_md/how-to-plugin.md) and
[`for-devs/code_samples/plugin_template.sh`](for-devs/code_samples/plugin_template.sh)
for the plugin API and examples.

Plugins are sourced into the main Bash process, so only run plugins you trust.

## Project structure

```text
Bash-Theft-Auto/
├── bta.sh                 # Current stable game script
├── bta-beta.sh            # Beta build
├── bta_testing.sh         # Testing build
├── plugins/               # Bash plugins
├── music/                 # Music tracks
├── sfx/                   # Sound effects
├── install-languages/     # Community language scripts
├── for-devs/              # Developer guides and code samples
├── pkg/                   # Packaging resources
├── BTA-archive/           # Older game versions
├── how-to-install.md      # Additional package installation notes
├── ver_checker.sh         # Remote version checker
├── version.txt            # Current release number
└── LICENSE                # MIT license for the code
```

## Development

The game is a single Bash application with a plugin system. When developing:

- Make changes to `bta.sh` unless you are specifically working on a beta or
  testing build.
- Test the game in Bash after changes.
- Keep save files, debug logs, and personal audio out of commits.
- Keep plugins self-contained and use descriptive names.
- Check the developer documentation in [`for-devs/`](for-devs/) before adding
  new game systems or plugins.

There is no automated test suite at present. A basic syntax check can be run
with:

```bash
bash -n bta.sh
bash -n bta-beta.sh
bash -n bta_testing.sh
```

## Contributing

Contributions, bug reports, ideas, and plugins are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make and test your changes.
4. Open a pull request with a clear description.

For bug reports, include your operating system, Bash version, reproduction
steps, expected behavior, actual behavior, and relevant terminal output.

## Licensing

The game code and animations are licensed under the
[MIT License](LICENSE).

Music and sound effects are separate assets. Music by stuffbymax / Martin
Petik is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Individual sound effects may have additional attribution or licensing
requirements; check the files in [`sfx/`](sfx/) before redistributing them.

## Links

- [Repository](https://github.com/stuffbymax/Bash-Theft-Auto)
- [Installation notes](how-to-install.md)
- [Developer resources](for-devs/)
- [Plugins](plugins/)

Have fun, and remember: **the terminal is your city.**

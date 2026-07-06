# Bash Theft Auto — Sound Effects Reference
**Version 2.5.0**
**ai generated**
All sound effects are `.mp3` files stored in the `sfx/` directory.  
Call them with: `play_sfx_mpg "name_without_extension"`

The function is always safe to call — it silently returns if the file doesn't exist or `mpg123` is not installed.

---

## Built-in SFX Names

| Name | Used When |
|---|---|
| `win` | Minor success (race win, small crime success) |
| `win_big` | Major success (heist, rank up, jackpot, perk unlock) |
| `lose` | Minor failure or damage |
| `lose_big` | Major failure (heist fail, gang war loss) |
| `wasted` | Player health reaches 0 |
| `cash_register` | Any cash transaction (buy, sell, bribe) |
| `heal` | Basic healing (food, health pack, basic treatment) |
| `heal_adv` | Advanced healing (adrenaline shot, advanced treatment) |
| `police_siren` | Wanted level increase, police events, ambush |
| `gun_cock` | Player draws a weapon |
| `gun_shot` | Gun bonus applied in a crime |
| `car_start` | Vehicle acquired or used |
| `air` | Air travel starts |
| `taxi` | Taxi job |
| `mechanic` | Mechanic job |
| `security` | Security guard job |
| `street_performer` | Performer job |
| `bus_driving` | Bus driver job |
| `bar` | Bartender job |
| `dock_worker` | Dock worker job |
| `construction` | Construction job |
| `food_prep` | Chef job |
| `pizza_delivery` | Pizza delivery job |
| `street_vendor` | Street vendor job |
| `burglary_stealth` | Burglary attempt start |
| `burglary_success` | Burglary succeeded |
| `burglary_fail` | Burglary failed |
| `hooker` | Hired a companion |
| `new_game` | New game started |
| `item_buy` | Item purchased from shop |
| `item_equip` | Item equipped (body armor) |
| `error` | Invalid action (e.g., buying armor you already have) |

---

## Adding Custom Sound Effects

1. Convert your audio to `.mp3` format
2. Place it in the `sfx/` directory: `sfx/my_sound.mp3`
3. Call it anywhere: `play_sfx_mpg "my_sound"`

**Recommended specs:** Mono or stereo, 128kbps MP3, short duration (under 5 seconds for effects)

---

## Music Files

Music files are separate from SFX and live in the `music/` directory.  
Any `.mp3` file placed there will appear in the in-game music player (option M from the main menu).

Music plays in the background via `mpg123` and is stopped cleanly on exit via the `cleanup_and_exit` trap.

---

## Licensing Note

The original BTA music and some SFX are © 2024 by stuffbymax - Martin Petik, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

If you add sounds from third-party sources, make sure you have the rights to use them and document licensing in your plugin's README or a `Creators.md` file in `sfx/`.
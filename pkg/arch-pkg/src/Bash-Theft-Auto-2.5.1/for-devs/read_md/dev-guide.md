# Bash Theft Auto — Developer Guide
**Version 2.5.0**
**ai generated**

> This guide covers everything you need to know to modify the core game, write plugins, add new mechanics, new cities, new gangs, new weapons, new jobs, new contacts, new perks, and more. Read it top to bottom at least once before touching the code.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Architecture Overview](#2-architecture-overview)
3. [Global State Variables](#3-global-state-variables)
4. [Core Systems Reference](#4-core-systems-reference)
   - [Clock System](#41-clock-system)
   - [Health System](#42-health-system)
   - [Wanted Level System](#43-wanted-level-system)
   - [Respect & City Reputation](#44-respect--city-reputation)
   - [Save / Load System](#45-save--load-system)
   - [Sound Effects](#46-sound-effects)
   - [World Events](#47-world-events)
5. [Plugin System](#5-plugin-system)
   - [How Plugins Are Loaded](#51-how-plugins-are-loaded)
   - [Plugin Hook Functions](#52-plugin-hook-functions)
   - [Plugin Save/Load Hooks](#53-plugin-saveload-hooks)
6. [Adding New Content](#6-adding-new-content)
   - [New City](#61-new-city)
   - [New Gang](#62-new-gang)
   - [New Weapon](#63-new-weapon)
   - [New Job](#64-new-job)
   - [New Crime](#65-new-crime)
   - [New Item](#66-new-item)
   - [New Perk](#67-new-perk)
   - [New Contact](#68-new-contact)
   - [New Main Menu Option](#69-new-main-menu-option)
   - [New Property / Business](#610-new-property--business)
7. [Modifying Existing Mechanics](#7-modifying-existing-mechanics)
8. [Coding Conventions & Rules](#8-coding-conventions--rules)
9. [Common Pitfalls](#9-common-pitfalls)
10. [Full Variable Quick-Reference](#10-full-variable-quick-reference)

---

## 1. Project Structure

```
bash-theft-auto/
├── bta_enhanced.sh          ← Main game script (do not rename)
├── plugins/                 ← Drop .sh plugin files here (auto-loaded)
│   ├── example_economy.sh
│   ├── example_missions.sh
│   └── ...
├── sfx/                     ← Sound effect .mp3 files
│   ├── win.mp3
│   ├── lose.mp3
│   └── ...  (see SFX_REFERENCE.md for full list)
├── music/                   ← Background music .mp3 files (any name)
├── saves/                   ← Auto-created by the game on first save
│   ├── player.sav
│   ├── time.sav
│   └── ...
└── docs/
    ├── DEVGUIDE.md          ← You are here
    ├── PLUGIN_API.md        ← Quick plugin API reference
    ├── SFX_REFERENCE.md     ← All sound effect names
    └── examples/
        ├── plugin_template.sh
        ├── plugin_new_city.sh
        ├── plugin_missions.sh
        ├── plugin_stock_market.sh
        └── plugin_bounty_board.sh
```

---

## 2. Architecture Overview

BTA is a **single-file bash game** with a **plugin system** bolted on top. The main loop looks like this:

```
run_initial_menu()
  └── Game_variables() or load_game()
        └── initialize_world_data()

while true; do
    update_world_state()          ← plugins can hook here
        run_clock 0
        passive_bounty_encounter  ← optional plugin hook
        tick_stock_market         ← optional plugin hook
        check_player_bounty()
    check_police_encounter()
    check_health()
    clear_screen()
    [show menu]
    [read choice]
    [dispatch to function]
done
```

All game state lives in **global bash variables**. Functions read and write these directly — there are no return values for state changes, only for computed numbers (which use `echo` and command substitution).

**Key design rule:** Every action that takes time calls `run_clock N` at its top. This keeps the world simulation consistent.

---

## 3. Global State Variables

### Player

| Variable | Type | Description |
|---|---|---|
| `player_name` | string | Player's chosen name |
| `location` | string | Current city name |
| `cash` | integer | Player's cash |
| `health` | integer | Player's health (0–100, can exceed briefly) |
| `body_armor_equipped` | bool | `true` / `false` |
| `wanted_level` | integer | 0–5 stars |
| `MAX_WANTED_LEVEL` | integer | Hard cap (5) |
| `player_respect` | integer | Global respect points |
| `perk_points` | integer | Unspent perk points |
| `last_respect_milestone` | integer | Last 1000-respect threshold crossed |

### Gang

| Variable | Type | Description |
|---|---|---|
| `player_gang` | string | Gang name or `"None"` |
| `player_gang_rank` | string | Current rank string |
| `player_recruits` | array | Each element: `"Name:Strength:Upkeep"` |
| `max_recruits` | integer | Max recruits allowed (set by `apply_gang_upgrades`) |
| `gang_upgrades` | assoc array | `["safe_house"]=N ["weapon_locker"]=N ["smuggling_routes"]=N` |
| `gang_relations` | assoc array | `["Gang Name"]="War/Hostile/Neutral"` |

### World

| Variable | Type | Description |
|---|---|---|
| `territory_owner` | assoc array | `["City\|District"]="Gang Name"` |
| `district_heat` | assoc array | `["City Name"]=integer` — police activity level |
| `available_properties` | assoc array | `["Name"]="price:city:type"` |
| `owned_businesses` | assoc array | `["Name"]="type=X status=Y"` |
| `city_reputation` | assoc array | `["City Name"]=0–100` |
| `protection_targets` | assoc array | `["Biz"]="city:weekly:heat:days"` |
| `protection_income` | assoc array | `["Biz"]=daily_income` |
| `world_event_log` | array | News feed strings (max 20) |
| `market_conditions` | assoc array | Drug market modifiers |

### Time

| Variable | Type | Description |
|---|---|---|
| `game_day` | integer | Current day number |
| `game_hour` | integer | Current hour (0–23) |

### Economy / Loan

| Variable | Type | Description |
|---|---|---|
| `loan_amount` | integer | Outstanding loan principal |
| `loan_interest` | integer | Accumulated interest |
| `loan_due_day` | integer | Day loan was taken |
| `loan_rate` | integer | Daily interest rate % |
| `loan_enforcer_warned` | bool | Whether enforcer warning was shown |

### Bounty / Contacts

| Variable | Type | Description |
|---|---|---|
| `player_bounty` | integer | Active bounty on player |
| `bounty_hitman_name` | string | Current hitman's name |
| `contacts_unlocked` | assoc array | `["contact_id"]=1` |
| `rented_safehouse` | string | City name or empty |
| `safehouse_rent_day` | integer | Day safe house was rented |

### Inventory

| Variable | Type | Description |
|---|---|---|
| `guns` | indexed array | Gun name strings |
| `items` | indexed array | Item name strings |
| `drugs` | assoc array | `["Drug Name"]=quantity` |
| `owned_vehicles` | indexed array | Vehicle type strings |
| `skills` | assoc array | `["skill_name"]=level_integer` |
| `perks` | assoc array | `["Perk Name"]=1` if owned |

---

## 4. Core Systems Reference

### 4.1 Clock System

```bash
run_clock <hours>
```

Call this at the **top of every action function** that consumes time. It:
- Advances `game_hour` and `game_day`
- Triggers `apply_wanted_decay` every 4 hours
- Triggers `process_world_events` at key times
- Calls `calculate_and_apply_payouts` on day rollover

**Example:**
```bash
my_new_action() {
    run_clock 2   # This action takes 2 in-game hours
    # ... your logic here
}
```

**Never** manually modify `game_hour` or `game_day` — always go through `run_clock`.

---

### 4.2 Health System

```bash
check_health    # Returns 0 (alive) or 1 (wasted, hospitalized)
```

After any action that reduces `health`, call `check_health`. If health hits 0, the player is sent to the hospital automatically.

```bash
# Dealing damage:
health=$(( health - damage_amount ))
check_health

# Healing (cap at 100 unless you have a reason to go over):
health=$(( health + heal_amount ))
(( health > 100 )) && health=100
```

Body armor halves damage and is removed after absorbing:
```bash
local damage=30
if $body_armor_equipped; then
    damage=$(( damage / 2 ))
    body_armor_equipped=false
fi
health=$(( health - damage ))
```

---

### 4.3 Wanted Level System

```bash
wanted_level=$(( wanted_level + N ))
(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
```

Always clamp after increasing. The `Master of Disguise` perk reduces wanted gain from crimes by 1 — check for it in crime functions:

```bash
local wanted_gain=1
if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
wanted_level=$(( wanted_level + wanted_gain ))
(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
```

Wanted level decays automatically via `apply_wanted_decay` every 4 in-game hours (called inside `run_clock`). You don't need to call this manually.

---

### 4.4 Respect & City Reputation

```bash
award_respect <amount>
```

**Always use `award_respect`** instead of directly modifying `player_respect`. It handles:
- Respect milestone detection (perk point awards)
- City reputation increase (1/10th of respect gained)
- Gang rank promotion checks

To deduct respect directly:
```bash
player_respect=$(( player_respect - amount ))
(( player_respect < 0 )) && player_respect=0
```

City reputation (`city_reputation[$location]`) is 0–100 and affects:
- Job pay bonus (`get_city_rep_bonus` returns 0/3/5/10/15%)
- Training gym discount
- Contact unlock thresholds
- Crime success at 80+ rep

---

### 4.5 Save / Load System

The save system uses flat key-value files in `saves/` with `@@@` as the delimiter.

**To save a new scalar variable**, add it to the `player.sav` block in `save_game`:
```bash
echo "my_variable@@@$my_variable" >> "$save_path/player.sav"
```

And load it in `load_game`:
```bash
"my_variable") my_variable="$value";;
```

**To save a new associative array**, use the helper:
```bash
save_assoc_array "$save_path/myarray.sav" "my_array_var_name"
load_assoc_array "$save_path/myarray.sav" "my_array_var_name"
```

**To save a new indexed array**, use the helper:
```bash
printf '%s\n' "${my_array[@]}" > "$save_path/myarray.sav"
load_indexed_array "$save_path/myarray.sav" "my_array_var_name"
```

**Plugins** should use the `bounty_save_extra` / `bounty_load_extra` hook pattern (see Section 5.3).

---

### 4.6 Sound Effects

```bash
play_sfx_mpg "sound_name"
```

This plays `sfx/sound_name.mp3` non-blocking. It silently fails if the file doesn't exist or mpg123 isn't installed — so it's always safe to call.

See `SFX_REFERENCE.md` for the full list of built-in sound names. To add your own:
1. Drop a `.mp3` into `sfx/`
2. Call `play_sfx_mpg "your_sound_name"` (without the `.mp3` extension)

---

### 4.7 World Events

```bash
process_world_events()
```

Called automatically by `run_clock`. AI gangs randomly attack territories. You can push custom events to the news feed from anywhere:

```bash
world_event_log+=("[Day $game_day] Your custom event text here.")
# Keep the log trimmed
if (( ${#world_event_log[@]} > 20 )); then
    world_event_log=("${world_event_log[@]:1}")
fi
```

---

## 5. Plugin System

### 5.1 How Plugins Are Loaded

All `.sh` files in the `plugins/` directory are **sourced** (not executed) at startup, before the main menu. This means every function and variable you define in a plugin becomes part of the game's global scope.

```bash
# From bta_enhanced.sh:
plugin_dir="plugins"
if [[ -d "$BASEDIR/$plugin_dir" ]]; then
    while IFS= read -r -d $'\0' plugin_script; do
        [[ -f "$plugin_script" ]] && source "$plugin_script"
    done < <(find "$BASEDIR/$plugin_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
fi
```

Plugins are loaded **before** `run_initial_menu` is called, so they can safely define functions, modify arrays, and register hooks.

**Plugin load order** is filesystem-alphabetical. If your plugin depends on another, prefix filenames with numbers: `01_base.sh`, `02_dependent.sh`.

---

### 5.2 Plugin Hook Functions

The main game checks for optional functions using `command -v`. If the function exists (defined by a plugin), it's called. If not, it's skipped.

| Hook Function | Called When | Purpose |
|---|---|---|
| `passive_bounty_encounter` | Every main loop tick (via `update_world_state`) | Passive timed bounty checks |
| `tick_stock_market` | Every main loop tick | Stock market price updates |
| `air_travel_animation` | During air travel | Custom travel animation |
| `drive_animation` | During vehicle travel | Custom drive animation |
| `buy_animation` | On gun purchase | Purchase animation |
| `working_animation` | During jobs | Job animation |
| `race_animation` | Street race start | Race animation |
| `robbing_animation` | Store robbery start | Robbery animation |
| `burglary_animation` | Burglary start | Burglary animation |
| `heist_animation` | Heist start | Heist animation |
| `carjacking_animation` | Carjacking start | Carjacking animation |
| `gang_war_animation` | Gang war start | War animation |
| `drug_transaction_animation` | Drug buy/sell | Transaction animation |

**How to register your own hook** (for the main loop):

The main loop calls `update_world_state` every tick. You can't easily inject into the main loop from a plugin, but you can override `update_world_state` by redefining it — **be careful** to call the original logic:

```bash
# In your plugin:
# Save original if it exists, then wrap it
_original_update_world_state=$(declare -f update_world_state)

update_world_state() {
    # Call original behavior
    run_clock 0
    command -v passive_bounty_encounter &>/dev/null && passive_bounty_encounter
    command -v tick_stock_market &>/dev/null && tick_stock_market
    check_player_bounty
    # Your new hook:
    command -v my_plugin_tick &>/dev/null && my_plugin_tick
}
```

---

### 5.3 Plugin Save/Load Hooks

The save and load functions call these optional hooks at their end:

```bash
command -v bounty_save_extra &>/dev/null && bounty_save_extra
command -v bounty_load_extra &>/dev/null && bounty_load_extra
command -v economy_save_extra &>/dev/null && economy_save_extra
command -v economy_load_extra &>/dev/null && economy_load_extra
```

**Name your plugin's save/load hooks after these patterns.** If your plugin is named `bounty_board`, use `bounty_save_extra` and `bounty_load_extra`. If it uses a different name, use `economy_save_extra` / `economy_load_extra`. 

For new plugins with a unique name, you have two options:

**Option A — Use an existing hook slot:**
```bash
bounty_save_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    echo "my_plugin_var@@@$my_plugin_var" >> "$save_path/my_plugin.sav"
}
bounty_load_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    [[ -f "$save_path/my_plugin.sav" ]] || return
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        local key="${line%%@@@*}"; local value="${line#*@@@}"
        case "$key" in
            "my_plugin_var") my_plugin_var="$value";;
        esac
    done < "$save_path/my_plugin.sav"
}
```

**Option B — Patch save_game and load_game directly** (see Section 6.9).

---

## 6. Adding New Content

### 6.1 New City

Cities exist as strings in `location`. To add a new city:

**Step 1 — Add to the travel menu** in the main game loop:
```bash
# In the travel case block (choice 1):
echo "8. New City (\$250)"
# ...
8) travel_to 250 "New City";;
```

**Step 2 — Add district heat** in `initialize_world_data`:
```bash
district_heat=(
    # ... existing ...
    ["New City"]=8
)
```

**Step 3 — Add territories** in `initialize_world_data`:
```bash
territory_owner=(
    # ... existing ...
    ["New City|Downtown New City"]="Unaffiliated"
    ["New City|East Side"]="Your New Gang"
)
```

**Step 4 — Add city reputation** in `initialize_world_data`:
```bash
city_reputation=(
    # ... existing ...
    ["New City"]=10
)
```

**Step 5 — Add properties** in `available_properties`:
```bash
["NC Corner Store"]="50000:New City:Legal"
["NC Drug Den"]="120000:New City:IllegalFront"
```

**Step 6 — Add job pay range** in `work_job`:
```bash
case "$location" in
    # ... existing ...
    "New City") min_earnings=30; max_earnings=90;;
esac
```

**Step 7 — Add drug market modifier** in `buy_drugs` and `sell_drugs`:
```bash
case "$location" in
    # ... existing ...
    "New City") location_modifier=5;;
esac
```

**Step 8 — Add protection targets** in `initialize_world_data`:
```bash
protection_targets=(
    # ... existing ...
    ["NC Kebab Shop"]="New City:75:10:0"
)
```

---

### 6.2 New Gang

**Step 1 — Register in `GANG_HOME_CITY`** inside `initialize_world_data`:
```bash
GANG_HOME_CITY=(
    # ... existing ...
    ["The Vipers"]="New City"
)
```

**Step 2 — Assign territory** in `territory_owner`:
```bash
["New City|The Viper Quarter"]="The Vipers"
```

That's all. The AI war system, diplomacy, and gang strength calculations will automatically include the new gang.

---

### 6.3 New Weapon

**Step 1 — Add attributes** to `gun_attributes` near the top of the script:
```bash
gun_attributes=(
    # ... existing ...
    ["Plasma Cutter"]="success_bonus=30"
)
```

The `success_bonus` is added to success chance when the weapon is used in crimes. Range: 1–30 is reasonable; anything above 28 is "best in class."

**Step 2 — Add to `buy_guns` menu:**
```bash
echo " 14. Plasma Cutter (\$1500) - Experimental energy weapon"
# ...
14) buy_gun "Plasma Cutter" 1500;;
# Update "Leave" option number accordingly
15) return;;
```

No other changes needed. The weapon will automatically work in all crime functions that call `apply_gun_bonus`.

---

### 6.4 New Job

**Step 1 — Add a case to `work_job`:**
```bash
"my_new_job")
    relevant_skill_name="strength"        # driving/strength/charisma/stealth/drug_dealer
    relevant_skill_level=${skills[$relevant_skill_name]:-1}
    skill_bonus=$(( relevant_skill_level * 3 ))
    play_sfx_mpg "my_sfx_name"            # optional, silently skipped if missing
    ;;
```

**Step 2 — Add to the Work (Legal) menu** in the main loop (choice 5):
```bash
echo "13. My New Job"
# ...
13) work_job "my_new_job";;
14) ;; # Back — increment this
```

The job will inherit the city pay range and city rep bonus automatically.

---

### 6.5 New Crime

Follow this template exactly — it ensures consistency with the wanted level, health, and respect systems:

```bash
my_new_crime() {
    run_clock 2   # How many hours this crime takes

    local relevant_skill=${skills[stealth]:-1}   # or strength/driving etc.
    local base_chance=$(( 20 + relevant_skill * 5 ))
    (( base_chance > 90 )) && base_chance=90

    clear_screen
    echo "--- My New Crime ---"
    echo "Your setup text here..."; sleep 1

    # Optional: use a gun for bonus
    local final_chance=$(apply_gun_bonus "$base_chance" "crime description")

    echo "Success chance: ${final_chance}%"
    read -r -p "Press Enter to attempt..."

    if (( RANDOM % 100 < final_chance )); then
        # SUCCESS
        local reward=$(( RANDOM % 201 + 100 + relevant_skill * 10 ))
        cash=$(( cash + reward ))
        health=$(( health - (RANDOM % 11 + 5) ))   # Minor damage even on success
        echo -e "\e[1;32mSuccess!\e[0m You earned \$$reward."
        play_sfx_mpg "cash_register"
        award_respect $(( RANDOM % 15 + 5 ))
        district_heat["$location"]=$(( ${district_heat[$location]:-0} + 3 ))
        # Optional: skill up
        if (( RANDOM % 3 == 0 )); then
            skills[stealth]=$(( relevant_skill + 1 ))
            echo "Your stealth skill increased!"
        fi
    else
        # FAILURE
        local wanted_gain=1
        if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
        wanted_level=$(( wanted_level + wanted_gain ))
        (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        if (( wanted_gain > 0 )); then
            echo -e "\e[1;31mCaught!\e[0m"
            play_sfx_mpg "police_siren"
        fi
        local fine=$(( RANDOM % 101 + 50 + wanted_level * 25 ))
        cash=$(( cash - fine )); (( cash < 0 )) && cash=0
        health=$(( health - (RANDOM % 21 + 10 + wanted_level * 5) ))
        echo "Fined \$$fine and took damage."
    fi

    check_health
    read -r -p "Press Enter..."
}
```

Then add it to the Criminal Activities menu (choice 6 in the main loop).

---

### 6.6 New Item

Items in BTA are strings stored in the `items` array. Usage logic lives in `use_item`.

**Step 1 — Add to `use_item`:**
```bash
"My New Item")
    echo "You use the My New Item..."
    # ... effect logic ...
    # Remove from inventory after use:
    items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}")
    ;;
```

**Step 2 — Add a way to obtain it** (shop, crime reward, auction, etc.):
```bash
items+=("My New Item")
```

**Step 3 — Add to `apply_auction_reward`** if it can appear at auctions:
```bash
"My New Item")
    items+=("My New Item")
    echo "My New Item added to inventory.";;
```

---

### 6.7 New Perk

**Step 1 — Add to `perk_costs`:**
```bash
declare -A perk_costs=(
    # ... existing ...
    ["Iron Fist"]=2
)
```

**Step 2 — Add to `perk_descriptions`:**
```bash
declare -A perk_descriptions=(
    # ... existing ...
    ["Iron Fist"]="Deal 25% more damage in fights."
)
```

**Step 3 — Add to a tier array:**
```bash
declare -a TIER_2_PERKS=("Master of Disguise" "Professional Driver" "Iron Fist")
```

**Step 4 — Apply the perk effect** wherever relevant by checking:
```bash
if [[ -v "perks[Iron Fist]" ]]; then
    damage=$(( damage * 125 / 100 ))
fi
```

---

### 6.8 New Contact

**Step 1 — Add to the `contact_info` associative array** inside `manage_phone_contacts`:
```bash
["my_contact"]="Display Name|Unlock: description of unlock condition|Benefit: what they do"
```

**Step 2 — Add to the unlock loop** in `check_contact_unlocks`:
```bash
if [[ ! -v "contacts_unlocked[my_contact]" ]] && (( some_condition )); then
    contacts_unlocked["my_contact"]=1
    world_event_log+=("[Day $game_day] New contact unlocked: Display Name")
fi
```

**Step 3 — Add to the `call_contact` case:**
```bash
"my_contact")
    echo "--- Display Name ---"
    echo "Their catchphrase."
    # ... active ability logic ...
    ;;
```

**Step 4 — Apply passive effects** wherever they're relevant by checking:
```bash
if [[ -v "contacts_unlocked[my_contact]" ]]; then
    # apply bonus
fi
```

---

### 6.9 New Main Menu Option

**Step 1 — Add to the menu display** in the main while loop:
```bash
echo "22. My New Feature  |"
```

**Step 2 — Add to the case statement:**
```bash
22) my_new_feature_function;;
```

**Step 3 — From a plugin**, you can't directly inject into the main loop's case statement. Instead, structure your plugin so your feature is accessible from an existing submenu (Gang Menu, Shops, etc.) or document that users must add the case manually.

---

### 6.10 New Property / Business

Add to `available_properties` in `initialize_world_data`:

```bash
["My Business Name"]="PRICE:CITY_NAME:TYPE"
```

Where `TYPE` is one of:
- `Legal` — earns `$200/day`
- `IllegalFront` — earns `$500/day + smuggling bonus`

The payout is applied automatically in `calculate_and_apply_payouts`.

---

## 7. Modifying Existing Mechanics

### Changing Base Prices / Costs

All prices are hardcoded inline. Search for the function and modify the number directly. Key locations:

| What | Where |
|---|---|
| Gun prices | `buy_guns()` — the case statement numbers |
| Vehicle prices | `vehicle_types` associative array (global) |
| Hospital costs | `buy_hospital_item()` — the parameters in `visit_hospital` |
| Drug base prices | `drug_prices` and `drug_sell_prices` local arrays in `buy_drugs/sell_drugs` |
| Loan rates | `take_loan()` — the rate parameter |
| Safe house rent | `SAFEHOUSE_RENT_COST` global variable |
| Tribute to gangs | `diplomacy_menu()` — `tribute_cost` local variable |

### Changing Success Chances

Every crime uses the pattern `base_chance + skill_multiplier`. The formula is:

```
final_chance = base_chance + (skill_level * multiplier) + gun_bonus + rep_bonus
```

Clamp to 5–95 to avoid guaranteed success/failure.

### Changing Wanted Level Decay Rate

In `run_clock`, modify the `decay_triggers` array. Currently decays every 4 hours — to make it every 6:
```bash
local decay_triggers=(6 12 18)
```

### Changing Daily Payouts

In `calculate_and_apply_payouts`:
- Territory income per district: change `150`
- Legal business income: change `200`
- Illegal business income: change `500`
- Smuggling bonus multiplier: change `100` (per level)

---

## 8. Coding Conventions & Rules

### Always Use `local` in Functions

```bash
my_function() {
    local my_var="value"   # GOOD
    my_var="value"          # BAD — pollutes global scope
}
```

Exception: when you intentionally want to set a global (e.g., `cash`, `health`). Be explicit about this with a comment.

### Never Use Subshells for State Changes

```bash
# BAD — changes inside $() are lost
result=$(cash=999; echo "done")

# GOOD — modify globals directly
cash=999
result="done"
```

### String Comparisons

```bash
# GOOD
[[ "$player_gang" == "None" ]]

# BAD — unquoted, prone to word splitting
[ $player_gang == None ]
```

### Integer Arithmetic

```bash
# GOOD — use (( )) for integer math
(( cash += 100 ))
cash=$(( cash + 100 ))

# BAD — string operations on numbers
cash="$cash+100"
```

### Associative Array Existence Check

```bash
# Check if a key exists:
if [[ -v "my_array[key]" ]]; then ...

# Check if array is non-empty:
if (( ${#my_array[@]} > 0 )); then ...
```

### Always Clamp Health and Wanted Level

```bash
health=$(( health - damage ))
# No automatic clamping — call check_health instead

wanted_level=$(( wanted_level + 1 ))
(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL

cash=$(( cash - cost ))
(( cash < 0 )) && cash=0
```

### Menu Pattern

All menus follow this standard pattern:
```bash
while true; do
    clear_screen
    echo "--- Menu Title ---"
    echo "1. Option A"
    echo "2. Option B"
    echo "B. Back"
    read -r -p "Choice: " choice
    case "$choice" in
        1) do_thing_a;;
        2) do_thing_b;;
        'b'|'B') return;;
        *) echo "Invalid."; sleep 1;;
    esac
done
```

---

## 9. Common Pitfalls

**1. Forgetting `run_clock`**
Your action takes time in the real world — the game should reflect this. Always call `run_clock N` at the top.

**2. Breaking `save_game` / `load_game`**
If you add new global variables, add them to both `save_game` and `load_game`. Missing a variable means it resets to its default on load.

**3. Using `exit` in Plugins**
Never call `exit` from a plugin. Use `return` to exit functions. The main trap handles clean shutdown.

**4. Sourcing Order Dependencies**
If your plugin depends on a function defined later in the main script, that's fine — bash resolves function calls at runtime, not at source time. But if Plugin B needs Plugin A's functions, ensure A is loaded first (alphabetical filename ordering).

**5. Echoing Inside Functions Used for Return Values**
Some functions use `echo` to "return" a value (e.g., `calculate_gang_strength`, `get_city_rep_bonus`, `apply_gun_bonus`). Don't add debug `echo` statements inside them — it will corrupt the return value.

**6. The `@@@` Delimiter**
The save system uses `@@@` as the key-value delimiter. Never use `@@@` in any game string value (city names, gang names, player names, etc.) or saves will corrupt.

**7. Associative Array Declarations in Functions**
In bash, `declare -A` inside a function creates a **local** array. If you need a global associative array set inside a function, declare it globally first, then assign inside the function.

---

## 10. Full Variable Quick-Reference

```bash
# ── PLAYER ──────────────────────────────────────────
player_name          # string
location             # string — current city
cash                 # integer
health               # integer (0–100+)
body_armor_equipped  # bool (true/false)
wanted_level         # integer (0–5)
MAX_WANTED_LEVEL     # integer constant = 5
player_respect       # integer
perk_points          # integer
last_respect_milestone  # integer

# ── SKILLS (assoc) ──────────────────────────────────
skills[driving]
skills[strength]
skills[charisma]
skills[stealth]
skills[drug_dealer]

# ── INVENTORY ────────────────────────────────────────
guns[@]              # indexed array of gun name strings
items[@]             # indexed array of item name strings
drugs[Weed]          # quantity integer
drugs[Cocaine]
drugs[Heroin]
drugs[Meth]
owned_vehicles[@]    # indexed array of vehicle type strings

# ── GANG ─────────────────────────────────────────────
player_gang          # string or "None"
player_gang_rank     # string
player_recruits[@]   # "Name:Strength:Upkeep" strings
max_recruits         # integer (set by apply_gang_upgrades)
gang_upgrades[safe_house]       # 0–3
gang_upgrades[weapon_locker]    # 0–3
gang_upgrades[smuggling_routes] # 0–3
gang_relations[Gang Name]       # "War"/"Hostile"/"Neutral"

# ── WORLD ────────────────────────────────────────────
territory_owner[City|District]  # gang name string
district_heat[City]             # integer
available_properties[Name]      # "price:city:type"
owned_businesses[Name]          # "type=X status=Y"
city_reputation[City]           # 0–100
protection_targets[Biz]         # "city:weekly:heat:days"
protection_income[Biz]          # integer daily income
world_event_log[@]              # string array (max 20)
market_conditions[crackdown_multiplier]
market_conditions[demand_multiplier]
market_conditions[buy_multiplier]
market_conditions[event_message]

# ── TIME ─────────────────────────────────────────────
game_day             # integer
game_hour            # integer (0–23)

# ── LOAN ─────────────────────────────────────────────
loan_amount          # integer principal
loan_interest        # integer accumulated interest
loan_due_day         # integer day taken
loan_rate            # integer % daily rate
loan_enforcer_warned # bool

# ── CONTACTS ─────────────────────────────────────────
contacts_unlocked[dealer]
contacts_unlocked[corrupt_cop]
contacts_unlocked[mechanic]
contacts_unlocked[fence_king]
contacts_unlocked[loan_fixer]

# ── BOUNTY ───────────────────────────────────────────
player_bounty        # integer
bounty_hitman_name   # string

# ── SAFE HOUSE ───────────────────────────────────────
rented_safehouse     # string city name or ""
safehouse_rent_day   # integer
SAFEHOUSE_RENT_COST  # integer constant = 200

# ── AUCTION ──────────────────────────────────────────
auction_active       # bool
current_auction[item]
current_auction[desc]
current_auction[type]
current_auction[value]
current_auction[min_bid]
current_auction[current_bid]
current_auction[ends_day]

# ── PERKS (assoc, key=perk name, value=1 if owned) ──
perks[Street Negotiator]
perks[Back Alley Surgeon]
perks[Grease Monkey]
perks[Master of Disguise]
perks[Professional Driver]
perks[Charismatic Leader]

# ── PATHS ────────────────────────────────────────────
BASEDIR              # absolute path to game directory
SAVE_DIR             # "saves" (relative to BASEDIR)
sfx_dir              # "sfx" (relative to BASEDIR)
```
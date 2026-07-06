# Bash Theft Auto — Plugin Quick Reference
**Version 2.5.0**
**ai generated**

Drop your `.sh` file into the `plugins/` folder. It gets sourced automatically at startup.

---

## Hook Functions (define these in your plugin to intercept game events)

| Function Name | Arguments | Called From | Notes |
|---|---|---|---|
| `passive_bounty_encounter` | none | `update_world_state` (every tick) | For passive timed events |
| `tick_stock_market` | none | `update_world_state` (every tick) | Economy plugin hook |
| `bounty_save_extra` | none | `save_game` | Save plugin state |
| `bounty_load_extra` | none | `load_game` | Load plugin state |
| `economy_save_extra` | none | `save_game` | Save plugin state (alt) |
| `economy_load_extra` | none | `load_game` | Load plugin state (alt) |
| `air_travel_animation` | `"from_city" "to_city"` | `travel_to` (air) | Visual only |
| `drive_animation` | `"from_city" "to_city"` | `travel_to` (vehicle) | Visual only |
| `buy_animation` | `"item_name"` | `buy_gun` | Visual only |
| `working_animation` | `"job_type"` | `work_job` | Visual only |
| `race_animation` | none | `street_race` | Visual only |
| `robbing_animation` | none | `rob_store` | Visual only |
| `burglary_animation` | none | `burglary` | Visual only |
| `heist_animation` | none | `heist` | Visual only |
| `carjacking_animation` | none | `carjack` | Visual only |
| `gang_war_animation` | none | `initiate_gang_war` | Visual only |
| `drug_transaction_animation` | `"buy"/"sell"` | `drug_transaction` | Visual only |

---

## Key Functions Your Plugin Can Call

```bash
run_clock <hours>               # Advance game time
award_respect <amount>          # Give player respect (handles rank/perk points)
check_health                    # Trigger wasted sequence if health <= 0
play_sfx_mpg "sound_name"       # Play a sound effect (non-blocking, safe to call always)
clear_screen                    # Print the HUD header
apply_gun_bonus <base> "label"  # Prompt gun use, returns adjusted success %
calculate_gang_strength "name"  # Returns integer strength of a gang
get_city_rep_bonus              # Returns % pay bonus for current city rep (0/3/5/10/15)
check_contact_unlocks           # Re-evaluate contact unlock conditions
```

---

## Minimal Plugin Template

```bash
#!/bin/bash
# Plugin: My Plugin Name
# Author: Your Name
# Description: What this plugin does

# ── State Variables ──────────────────────────────────────────────────────────
my_plugin_counter=0
declare -A my_plugin_data=()

# ── Save / Load Hooks ────────────────────────────────────────────────────────
bounty_save_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    {
        echo "my_plugin_counter@@@$my_plugin_counter"
    } > "$save_path/my_plugin.sav"
    # For associative arrays:
    # save_assoc_array "$save_path/my_plugin_data.sav" "my_plugin_data"
}

bounty_load_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    [[ -f "$save_path/my_plugin.sav" ]] || return
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        local key="${line%%@@@*}"; local value="${line#*@@@}"
        case "$key" in
            "my_plugin_counter") my_plugin_counter="$value";;
        esac
    done < "$save_path/my_plugin.sav"
    # For associative arrays:
    # load_assoc_array "$save_path/my_plugin_data.sav" "my_plugin_data"
}

# ── Main Feature Function ────────────────────────────────────────────────────
my_plugin_main() {
    run_clock 1
    clear_screen
    echo "--- My Plugin ---"
    printf " Cash: \$%d | Day: %d\n" "$cash" "$game_day"
    echo "========================"
    echo "1. Do something"
    echo "2. Back"
    read -r -p "Choice: " choice
    case "$choice" in
        1) do_something;;
        2) return;;
        *) echo "Invalid."; sleep 1;;
    esac
}

do_something() {
    my_plugin_counter=$(( my_plugin_counter + 1 ))
    echo "Done! Counter: $my_plugin_counter"
    award_respect 10
    read -r -p "Press Enter..."
}

# ── Optional: Passive Tick Hook ──────────────────────────────────────────────
# Uncomment to run every main loop iteration:
# passive_bounty_encounter() {
#     (( RANDOM % 100 < 5 )) || return
#     echo "My plugin passive event!"
#     read -r -p "Press Enter..."
# }
```

---

## Adding Your Feature to the Main Menu

Since plugins can't inject into the main loop's `case` statement directly, there are two approaches:

**Approach A — Patch an existing submenu** (recommended for most plugins):
```bash
# Override visit_shop to add your option
_bta_original_visit_shop() {
    # Copy the original visit_shop body here if you need to call it
    :
}

visit_shop() {
    run_clock 1
    clear_screen
    echo "--- Street Shops in ${location} ---"
    echo "1. Convenience Store"
    echo "2. Black Market"
    echo "3. Clothing Store"
    echo "4. My Plugin Shop"   # ← your addition
    echo "5. Back"
    read -r -p "Choice: " shop_choice
    case "$shop_choice" in
        1) convenience_store;;
        2) black_market;;
        3) clothing_store;;
        4) my_plugin_main;;   # ← your addition
        5) return;;
        *) echo "Invalid." && sleep 1;;
    esac
}
```

**Approach B — Document manual patching** for your plugin's README:
Tell users to add one line to the main menu echo block and one line to the case statement.

---

## Save File Format

Save files live in `saves/`. Each line is `KEY@@@VALUE`. Never use `@@@` in any value string.

Your plugin's save file should be named `my_plugin_name.sav` and stored in the same `saves/` directory.

---

## Useful Patterns

### Random event with a chance
```bash
(( RANDOM % 100 < 15 )) || return   # 15% chance, return if not triggered
```

### Add to news feed
```bash
world_event_log+=("[Day $game_day] Your news text here.")
if (( ${#world_event_log[@]} > 20 )); then
    world_event_log=("${world_event_log[@]:1}")
fi
```

### Check if player is in a specific city
```bash
[[ "$location" == "Las Venturas" ]] || { echo "Only in Las Venturas."; read -r -p "Press Enter..."; return; }
```

### Check if player is in a gang
```bash
[[ "$player_gang" != "None" ]] || { echo "Join a gang first."; read -r -p "Press Enter..."; return; }
```

### Temporarily boost a skill
```bash
local old_val=${skills[strength]:-1}
skills[strength]=$(( old_val + 5 ))
# ... do something ...
skills[strength]=$old_val
```

### Give a random item from a list
```bash
local -a loot_table=("Health Pack" "Fake ID" "Stolen Goods" "Adrenaline Shot")
items+=("${loot_table[RANDOM % ${#loot_table[@]}]}")
```
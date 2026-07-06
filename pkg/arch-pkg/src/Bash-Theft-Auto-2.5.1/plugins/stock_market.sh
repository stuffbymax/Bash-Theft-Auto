#!/bin/bash
# =============================================================================
# Plugin: Underworld Stock Market & Economy
# File:   plugins/stock_market.sh
# Author: stuffbymax / Martin Petik (plugin template)
# Ver:    1.0.0
# Desc:   A full underground economy system including:
#         - Volatile stock market with city-based companies
#         - Insider trading via informants / gang connections
#         - Money laundering through owned businesses
#         - Loan shark system with compounding interest
#         - Black market auctions for rare items / vehicles
# License: MIT
# =============================================================================

# --- Economy State ---
declare -A stock_portfolio=()       # ["TICKER"]="shares_owned:avg_buy_price"
declare -A stock_prices=()          # ["TICKER"]="current_price"
declare -A stock_history=()         # ["TICKER"]="p1,p2,p3,p4,p5"  (last 5 days)
declare -A stock_insider_tips=()    # ["TICKER"]="direction:confidence:expires_day"
stock_market_last_tick=0            # game_day of last price update

# Loan shark state
loan_principal=0
loan_interest_rate=15               # % per day
loan_days_outstanding=0
loan_taken_day=0
loan_shark_active=false

# Laundering state
declare -A laundering_jobs=()       # ["prop_name"]="dirty_cash:rate:started_day"
total_laundered=0

# Auction state
declare -A auction_items=()         # ["item_name"]="base_price:description:type:expires_day"
auction_last_refresh=0

# =============================================================================
# STOCK DEFINITIONS
# Format: TICKER="CompanyName:BasePrice:Volatility(1-5):City:Sector"
# =============================================================================
declare -A STOCK_DEFS=(
    ["MAZE"]="Maze Bank:45:2:Los Santos:Finance"
    ["AGON"]="Agony Solutions Inc:12:4:Los Santos:Pharma"
    ["BOLS"]="Bols Koshka Imports:88:3:Liberty City:Shipping"
    ["FICK"]="Fickett & Sons Law:55:1:Liberty City:Legal"
    ["TWIT"]="Tw@ Internet Cafes:8:5:San Fierro:Tech"
    ["VOID"]="Void Security Systems:33:3:San Fierro:Security"
    ["LVCL"]="LV Club Holdings:120:3:Las Venturas:Entertainment"
    ["LUCK"]="Lucky Strike Casinos:200:4:Las Venturas:Gambling"
    ["TRPC"]="Tropic Paradise Resorts:75:2:Vice City:Tourism"
    ["CRBN"]="Carbon Fuel Corp:62:3:Blaine County:Energy"
    ["AMMU"]="Ammu-Nation Ltd:95:2:Los Santos:Weapons"
    ["LSCM"]="LS Custom Motors:40:3:Los Santos:Auto"
    ["VSTR"]="Vangelico Street:180:2:Los Santos:Luxury"
    ["CAYO"]="Cayo Cartel Holdings:25:5:Vice City:Illegal"
    ["GHST"]="Ghosthawk Aviation:310:2:Liberty City:Aviation"
)

# =============================================================================
# PRICE ENGINE
# =============================================================================

init_stock_prices() {
    for ticker in "${!STOCK_DEFS[@]}"; do
        if [[ ! -v "stock_prices[$ticker]" ]]; then
            local def="${STOCK_DEFS[$ticker]}"
            local name base_price volatility city sector
            IFS=':' read -r name base_price volatility city sector <<< "$def"
            stock_prices["$ticker"]=$base_price
            stock_history["$ticker"]="${base_price},${base_price},${base_price},${base_price},${base_price}"
        fi
    done
}

tick_stock_market() {
    # Only tick once per game day
    (( game_day <= stock_market_last_tick )) && return
    stock_market_last_tick=$game_day
    init_stock_prices

    for ticker in "${!STOCK_DEFS[@]}"; do
        local def="${STOCK_DEFS[$ticker]}"
        local name base_price volatility city sector
        IFS=':' read -r name base_price volatility city sector <<< "$def"

        local current=${stock_prices[$ticker]}
        local heat=${district_heat[$city]:-0}

        # Base random movement scaled by volatility
        local swing=$(( RANDOM % (volatility * 10 + 1) - (volatility * 5) ))

        # Heat in the city increases volatility for local stocks
        if (( heat > 20 )); then
            local heat_swing=$(( RANDOM % 10 - 8 ))  # Mostly negative when heat is high
            swing=$(( swing + heat_swing ))
        fi

        # Insider tip influence
        if [[ -v "stock_insider_tips[$ticker]" ]]; then
            local tip="${stock_insider_tips[$ticker]}"
            local direction confidence expires
            IFS=':' read -r direction confidence expires <<< "$tip"
            if (( game_day <= expires )); then
                if [[ "$direction" == "up" ]]; then
                    swing=$(( swing + (RANDOM % confidence + confidence / 2) ))
                else
                    swing=$(( swing - (RANDOM % confidence + confidence / 2) ))
                fi
            else
                unset "stock_insider_tips[$ticker]"
            fi
        fi

        # Apply world events: if the player's gang controls the city, slight positive bias
        if [[ "$player_gang" != "None" ]]; then
            local player_territories=0
            for key in "${!territory_owner[@]}"; do
                local t_city="${key%|*}"
                if [[ "$t_city" == "$city" && "${territory_owner[$key]}" == "$player_gang" ]]; then
                    (( player_territories++ ))
                fi
            done
            if (( player_territories > 3 )); then
                swing=$(( swing + 2 ))
            fi
        fi

        # Calculate new price
        local new_price=$(( current + swing ))
        (( new_price < 1 )) && new_price=1

        stock_prices["$ticker"]=$new_price

        # Update history (shift left, append new)
        local hist="${stock_history[$ticker]}"
        local -a hist_arr
        IFS=',' read -ra hist_arr <<< "$hist"
        hist_arr=("${hist_arr[@]:1}" "$new_price")  # drop oldest, add newest
        stock_history["$ticker"]=$(IFS=','; echo "${hist_arr[*]}")
    done

    # Compound loan interest daily
    if $loan_shark_active && (( loan_principal > 0 )); then
        loan_days_outstanding=$(( game_day - loan_taken_day ))
        local interest=$(( loan_principal * loan_interest_rate / 100 ))
        loan_principal=$(( loan_principal + interest ))
        if (( loan_days_outstanding > 7 )); then
            echo -e "\e[1;31m*** LOAN SHARK WARNING ***\e[0m"
            echo "You are ${loan_days_outstanding} days overdue. Total owed: \$${loan_principal}"
            echo "The collectors are getting impatient..."
            if (( loan_days_outstanding > 14 )); then
                local penalty=$(( RANDOM % 30 + 10 ))
                health=$(( health - penalty ))
                echo -e "\e[1;31mThey sent someone to rough you up! Lost ${penalty}%% health.\e[0m"
                play_sfx_mpg "lose"
            fi
            read -r -p "Press Enter..."
        fi
    fi
}

# =============================================================================
# STOCK MARKET TERMINAL
# =============================================================================

show_stock_market() {
    run_clock 1
    tick_stock_market
    init_stock_prices

    while true; do
        clear_screen
        echo "--- Underground Stock Terminal ---"
        echo "  Accessed via encrypted connection. Day: ${game_day}"
        printf "  Your Cash: \$%d\n" "$cash"
        echo "================================================================="
        printf " %-6s %-25s %-8s %-8s %-10s %-5s\n" "TICK" "COMPANY" "PRICE" "CHANGE" "TREND" "CITY"
        echo "-----------------------------------------------------------------"

        local -a ticker_list=()
        for ticker in "${!STOCK_DEFS[@]}"; do
            ticker_list+=("$ticker")
        done
        # Sort alphabetically for consistent display
        IFS=$'\n' ticker_list=($(sort <<< "${ticker_list[*]}")); unset IFS

        local i=1
        local -a display_tickers=()
        for ticker in "${ticker_list[@]}"; do
            local def="${STOCK_DEFS[$ticker]}"
            local name base_price volatility city sector
            IFS=':' read -r name base_price volatility city sector <<< "$def"

            local current=${stock_prices[$ticker]:-$base_price}
            local hist="${stock_history[$ticker]}"
            local -a hist_arr
            IFS=',' read -ra hist_arr <<< "$hist"
            local prev=${hist_arr[-2]:-$current}
            local change=$(( current - prev ))

            local change_str color trend
            if (( change > 0 )); then
                change_str="+${change}"
                color="\e[1;32m"
                trend="▲"
            elif (( change < 0 )); then
                change_str="${change}"
                color="\e[1;31m"
                trend="▼"
            else
                change_str="0"
                color="\e[0m"
                trend="─"
            fi

            # Check if we own shares
            local owned_str=""
            if [[ -v "stock_portfolio[$ticker]" ]]; then
                local shares avg
                IFS=':' read -r shares avg <<< "${stock_portfolio[$ticker]}"
                owned_str="[${shares}sh]"
            fi

            # Insider tip indicator
            local tip_str=""
            if [[ -v "stock_insider_tips[$ticker]" ]]; then
                tip_str="★"
            fi

            printf " %-3d %-5s %-24s ${color}%-8d %-8s\e[0m %-3s %-5s %-14s %s\n" \
                "$i" "$ticker" "${name:0:24}" "$current" "$change_str" \
                "$trend" "$tip_str" "$city" "$owned_str"

            display_tickers+=("$ticker")
            ((i++))
        done

        echo "================================================================="
        echo " Portfolio value: \$$(calculate_portfolio_value)"
        echo "-----------------------------------------------------------------"
        echo " B. Buy shares     S. Sell shares    P. View Portfolio"
        echo " H. Price history  I. Insider tips   X. Exit market"
        echo "================================================================="
        read -r -p "Choice: " mkt_choice

        case "${mkt_choice,,}" in
            b) stock_buy_menu "${display_tickers[@]}" ;;
            s) stock_sell_menu "${display_tickers[@]}" ;;
            p) show_portfolio ;;
            h) show_price_history "${display_tickers[@]}" ;;
            i) show_insider_tips ;;
            x) return ;;
            *) echo "Invalid."; sleep 1 ;;
        esac
    done
}

calculate_portfolio_value() {
    local total=0
    for ticker in "${!stock_portfolio[@]}"; do
        local shares avg
        IFS=':' read -r shares avg <<< "${stock_portfolio[$ticker]}"
        local current=${stock_prices[$ticker]:-0}
        total=$(( total + shares * current ))
    done
    echo "$total"
}

stock_buy_menu() {
    local -a tickers=("$@")
    clear_screen
    echo "--- Buy Shares ---"
    printf " Cash available: \$%d\n" "$cash"
    echo "================================"
    local i=1
    for ticker in "${tickers[@]}"; do
        local def="${STOCK_DEFS[$ticker]}"
        local name base vol city sector
        IFS=':' read -r name base vol city sector <<< "$def"
        local current=${stock_prices[$ticker]:-$base}
        printf " %2d. %-5s %-22s \$%d/share\n" "$i" "$ticker" "$name" "$current"
        ((i++))
    done
    echo " B. Back"
    read -r -p "Select stock number: " sel
    [[ "${sel,,}" == "b" ]] && return
    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#tickers[@]} )); then
        echo "Invalid."; sleep 1; return
    fi

    local chosen_ticker="${tickers[$((sel-1))]}"
    local current=${stock_prices[$chosen_ticker]}
    local max_shares=$(( cash / current ))

    printf "\n%s is trading at \$%d/share.\n" "$chosen_ticker" "$current"
    printf "You can afford up to %d shares.\n" "$max_shares"
    read -r -p "How many shares to buy? " qty

    if ! [[ "$qty" =~ ^[1-9][0-9]*$ ]]; then echo "Invalid quantity."; read -r -p "Press Enter..."; return; fi
    local total_cost=$(( qty * current ))
    if (( cash < total_cost )); then
        echo "Not enough cash. Need \$${total_cost}."; read -r -p "Press Enter..."; return
    fi

    cash=$(( cash - total_cost ))

    # Update portfolio with weighted average
    if [[ -v "stock_portfolio[$chosen_ticker]" ]]; then
        local existing_shares existing_avg
        IFS=':' read -r existing_shares existing_avg <<< "${stock_portfolio[$chosen_ticker]}"
        local new_shares=$(( existing_shares + qty ))
        local new_avg=$(( (existing_shares * existing_avg + qty * current) / new_shares ))
        stock_portfolio["$chosen_ticker"]="${new_shares}:${new_avg}"
    else
        stock_portfolio["$chosen_ticker"]="${qty}:${current}"
    fi

    echo -e "\e[1;32mPurchased ${qty} shares of ${chosen_ticker} at \$${current}/share.\e[0m"
    echo "Total spent: \$${total_cost}"
    play_sfx_mpg "cash_register"
    read -r -p "Press Enter..."
}

stock_sell_menu() {
    local -a tickers=("$@")
    clear_screen
    echo "--- Sell Shares ---"

    if (( ${#stock_portfolio[@]} == 0 )); then
        echo "You don't own any shares."; read -r -p "Press Enter..."; return
    fi

    local i=1
    local -a owned_tickers=()
    for ticker in "${!stock_portfolio[@]}"; do
        local shares avg
        IFS=':' read -r shares avg <<< "${stock_portfolio[$ticker]}"
        local current=${stock_prices[$ticker]:-0}
        local gain=$(( (current - avg) * shares ))
        local gain_str color
        if (( gain >= 0 )); then
            gain_str="+\$${gain}"; color="\e[1;32m"
        else
            gain_str="-\$$(( -gain ))"; color="\e[1;31m"
        fi
        printf " %d. %-5s %4d shares @ \$%d (avg \$%d) P&L: %b%s\e[0m\n" \
            "$i" "$ticker" "$shares" "$current" "$avg" "$color" "$gain_str"
        owned_tickers+=("$ticker")
        ((i++))
    done
    echo " B. Back"
    read -r -p "Select stock to sell: " sel
    [[ "${sel,,}" == "b" ]] && return
    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#owned_tickers[@]} )); then
        echo "Invalid."; sleep 1; return
    fi

    local chosen_ticker="${owned_tickers[$((sel-1))]}"
    local shares avg
    IFS=':' read -r shares avg <<< "${stock_portfolio[$chosen_ticker]}"
    local current=${stock_prices[$chosen_ticker]:-0}

    printf "You own %d shares of %s. Current price: \$%d\n" "$shares" "$chosen_ticker" "$current"
    read -r -p "Sell how many shares? (max ${shares}): " qty

    if ! [[ "$qty" =~ ^[1-9][0-9]*$ ]] || (( qty > shares )); then
        echo "Invalid quantity."; read -r -p "Press Enter..."; return
    fi

    local proceeds=$(( qty * current ))
    cash=$(( cash + proceeds ))

    local remaining=$(( shares - qty ))
    if (( remaining == 0 )); then
        unset "stock_portfolio[$chosen_ticker]"
    else
        stock_portfolio["$chosen_ticker"]="${remaining}:${avg}"
    fi

    local pnl=$(( (current - avg) * qty ))
    echo -e "\e[1;32mSold ${qty} shares of ${chosen_ticker} for \$${proceeds}.\e[0m"
    if (( pnl >= 0 )); then
        echo -e "Profit: \e[1;32m+\$${pnl}\e[0m"
        award_respect $(( pnl / 500 + 1 ))
    else
        echo -e "Loss: \e[1;31m-\$$(( -pnl ))\e[0m"
    fi
    play_sfx_mpg "cash_register"
    read -r -p "Press Enter..."
}

show_portfolio() {
    clear_screen
    echo "--- Your Portfolio ---"
    if (( ${#stock_portfolio[@]} == 0 )); then
        echo "You own no shares."; read -r -p "Press Enter..."; return
    fi
    echo "======================================================"
    local total_invested=0 total_value=0
    for ticker in "${!stock_portfolio[@]}"; do
        local shares avg
        IFS=':' read -r shares avg <<< "${stock_portfolio[$ticker]}"
        local current=${stock_prices[$ticker]:-0}
        local invested=$(( shares * avg ))
        local value=$(( shares * current ))
        local pnl=$(( value - invested ))
        total_invested=$(( total_invested + invested ))
        total_value=$(( total_value + value ))
        local pnl_color="\e[1;32m"; (( pnl < 0 )) && pnl_color="\e[1;31m"
        printf " %-5s %4dsh  Invested:\$%-8d Value:\$%-8d P&L:%b%+d\e[0m\n" \
            "$ticker" "$shares" "$invested" "$value" "$pnl_color" "$pnl"
    done
    echo "======================================================"
    local total_pnl=$(( total_value - total_invested ))
    printf " Total Invested: \$%d\n" "$total_invested"
    printf " Total Value:    \$%d\n" "$total_value"
    local pnl_color="\e[1;32m"; (( total_pnl < 0 )) && pnl_color="\e[1;31m"
    printf " Total P&L:      %b%+d\e[0m\n" "$pnl_color" "$total_pnl"
    echo "======================================================"
    read -r -p "Press Enter..."
}

show_price_history() {
    local -a tickers=("$@")
    clear_screen
    echo "--- Price History (Last 5 Days) ---"
    echo "========================================"
    for ticker in "${tickers[@]}"; do
        local hist="${stock_history[$ticker]}"
        local current=${stock_prices[$ticker]:-0}
        printf " %-5s \$%-6d  History: %s\n" "$ticker" "$current" "$hist"
    done
    echo "========================================"
    read -r -p "Press Enter..."
}

# =============================================================================
# INSIDER TRADING
# =============================================================================

show_insider_tips() {
    run_clock 1
    clear_screen
    echo "--- Insider Trading Tips ---"
    echo "Obtained through gang connections and paid informants."
    echo "★ marks stocks with active tips."
    echo "================================================"

    local charisma=${skills[charisma]:-1}
    local gang_bonus=0
    [[ "$player_gang" != "None" ]] && gang_bonus=10

    echo "Options:"
    echo " 1. Buy a tip from a contact            (\$1000)"
    echo " 2. Use gang intel for market tip        (Requires gang, \$500)"
    echo " 3. View current active tips"
    echo " B. Back"
    read -r -p "Choice: " tip_choice

    case "${tip_choice,,}" in
        1)
            if (( cash < 1000 )); then echo "Not enough cash."; read -r -p "Press Enter..."; return; fi
            cash=$(( cash - 1000 ))
            _generate_insider_tip "$charisma"
            ;;
        2)
            if [[ "$player_gang" == "None" ]]; then
                echo "You need gang connections for this."; read -r -p "Press Enter..."; return
            fi
            if (( cash < 500 )); then echo "Not enough cash."; read -r -p "Press Enter..."; return; fi
            cash=$(( cash - 500 ))
            _generate_insider_tip $(( charisma + 3 ))
            ;;
        3)
            if (( ${#stock_insider_tips[@]} == 0 )); then
                echo "No active tips right now."
            else
                for ticker in "${!stock_insider_tips[@]}"; do
                    local tip="${stock_insider_tips[$ticker]}"
                    local direction confidence expires
                    IFS=':' read -r direction confidence expires <<< "$tip"
                    local dir_color="\e[1;32m"; [[ "$direction" == "down" ]] && dir_color="\e[1;31m"
                    printf " %-5s  Direction: %b%-4s\e[0m  Confidence: %d%%  Expires: Day %d\n" \
                        "$ticker" "$dir_color" "$direction" "$confidence" "$expires"
                done
            fi
            ;;
        b) return ;;
        *) echo "Invalid."; sleep 1 ;;
    esac
    read -r -p "Press Enter..."
}

_generate_insider_tip() {
    local charisma=$1
    local -a all_tickers=("${!STOCK_DEFS[@]}")
    local chosen="${all_tickers[RANDOM % ${#all_tickers[@]}]}"

    local direction
    (( RANDOM % 2 == 0 )) && direction="up" || direction="down"

    local confidence=$(( RANDOM % 30 + 40 + charisma * 2 ))
    (( confidence > 90 )) && confidence=90

    local expires=$(( game_day + RANDOM % 3 + 2 ))

    stock_insider_tips["$chosen"]="${direction}:${confidence}:${expires}"

    local dir_color="\e[1;32m"; [[ "$direction" == "down" ]] && dir_color="\e[1;31m"
    echo ""
    echo "Your contact leans in close..."
    sleep 1
    printf " \e[1;33m%s\e[0m is expected to go %b%s\e[0m over the next few days.\n" \
        "$chosen" "$dir_color" "$direction"
    printf " Confidence level: %d%% | Active until Day %d\n" "$confidence" "$expires"
    echo ""
    echo "The tip has been applied. Watch the market."
    play_sfx_mpg "cash_register"
}

# =============================================================================
# MONEY LAUNDERING
# =============================================================================

money_laundering_menu() {
    run_clock 1
    if (( ${#owned_businesses[@]} == 0 )); then
        echo "You need to own businesses to launder money."
        echo "Buy properties through the Gang & Empire menu."
        read -r -p "Press Enter..."; return
    fi

    while true; do
        clear_screen
        echo "--- Money Laundering Operations ---"
        printf " Dirty cash available: \$%d (your current cash)\n" "$cash"
        printf " Total laundered (lifetime): \$%d\n" "$total_laundered"
        echo "================================================"
        echo " Active launder jobs:"
        local has_active=false
        for prop in "${!laundering_jobs[@]}"; do
            has_active=true
            local dirty rate started
            IFS=':' read -r dirty rate started <<< "${laundering_jobs[$prop]}"
            local days_running=$(( game_day - started ))
            local cleaned=$(( dirty * rate * days_running / 100 ))
            (( cleaned > dirty )) && cleaned=$dirty
            local remaining=$(( dirty - cleaned ))
            printf "  %-25s  \$%d dirty | \$%d cleaned | ~%d%% done\n" \
                "$prop" "$remaining" "$cleaned" "$(( cleaned * 100 / dirty ))"
        done
        $has_active || echo "  (None active)"
        echo "================================================"
        echo " 1. Start new launder job"
        echo " 2. Collect cleaned money"
        echo " B. Back"
        read -r -p "Choice: " laund_choice

        case "${laund_choice,,}" in
            1) start_launder_job ;;
            2) collect_laundered_money ;;
            b) return ;;
            *) echo "Invalid."; sleep 1 ;;
        esac
    done
}

start_launder_job() {
    clear_screen
    echo "--- Start Laundering Job ---"
    echo "Choose a business to funnel money through:"
    echo "  (Higher-value illegal fronts clean money faster)"
    echo "================================================"

    local i=1
    local -a prop_keys=()
    for prop in "${!owned_businesses[@]}"; do
        local prop_type="${owned_businesses[$prop]}"
        if [[ -v "laundering_jobs[$prop]" ]]; then
            printf " %2d. %-25s [BUSY - Already laundering]\n" "$i" "$prop"
        else
            local rate=5
            [[ "$prop_type" == *"IllegalFront"* ]] && rate=15
            [[ "$prop_type" == *"Legal"* ]] && rate=8
            printf " %2d. %-25s [%s | Rate: %d%%/day]\n" "$i" "$prop" "$prop_type" "$rate"
        fi
        prop_keys+=("$prop")
        ((i++))
    done
    echo " B. Back"
    read -r -p "Select business: " sel
    [[ "${sel,,}" == "b" ]] && return
    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#prop_keys[@]} )); then
        echo "Invalid."; sleep 1; return
    fi

    local chosen_prop="${prop_keys[$((sel-1))]}"
    if [[ -v "laundering_jobs[$chosen_prop]" ]]; then
        echo "That business is already running a launder job."; read -r -p "Press Enter..."; return
    fi

    local prop_type="${owned_businesses[$chosen_prop]}"
    local rate=5
    [[ "$prop_type" == *"IllegalFront"* ]] && rate=15
    [[ "$prop_type" == *"Legal"* ]] && rate=8

    read -r -p "How much cash to launder? (Available: \$${cash}): " amount
    if ! [[ "$amount" =~ ^[1-9][0-9]*$ ]] || (( amount > cash )); then
        echo "Invalid amount or not enough cash."; read -r -p "Press Enter..."; return
    fi

    local fee=$(( amount * 10 / 100 ))  # 10% laundering fee
    local net=$(( amount - fee ))
    echo ""
    echo "Laundering fee: \$${fee} (10%)"
    echo "You will receive: \$${net} clean money"
    echo "Estimated completion: $(( 100 / rate )) days"
    read -r -p "Proceed? (y/n): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return

    cash=$(( cash - amount ))
    laundering_jobs["$chosen_prop"]="${net}:${rate}:${game_day}"
    echo -e "\e[1;32mLaundering job started.\e[0m Money is being funnelled through ${chosen_prop}."
    play_sfx_mpg "cash_register"
    read -r -p "Press Enter..."
}

collect_laundered_money() {
    clear_screen
    echo "--- Collect Laundered Funds ---"

    if (( ${#laundering_jobs[@]} == 0 )); then
        echo "No active laundering jobs."; read -r -p "Press Enter..."; return
    fi

    local collected_any=false
    local -a finished_jobs=()

    for prop in "${!laundering_jobs[@]}"; do
        local dirty rate started
        IFS=':' read -r dirty rate started <<< "${laundering_jobs[$prop]}"
        local days_running=$(( game_day - started ))
        local cleaned=$(( dirty * rate * days_running / 100 ))
        (( cleaned > dirty )) && cleaned=$dirty

        if (( cleaned > 0 )); then
            cash=$(( cash + cleaned ))
            total_laundered=$(( total_laundered + cleaned ))
            local remaining=$(( dirty - cleaned ))
            echo -e "Collected \e[1;32m\$${cleaned}\e[0m from ${prop}."
            collected_any=true

            if (( remaining <= 0 )); then
                finished_jobs+=("$prop")
                echo "  Job complete. Business is free for the next run."
            else
                # Update job with remaining amount and reset timer
                laundering_jobs["$prop"]="${remaining}:${rate}:${game_day}"
                echo "  \$${remaining} still being cleaned."
            fi
        else
            echo "${prop}: Not ready yet. Come back in $(( (100/rate) - days_running )) day(s)."
        fi
    done

    for prop in "${finished_jobs[@]}"; do
        unset "laundering_jobs[$prop]"
    done

    $collected_any || echo "Nothing ready to collect yet."
    play_sfx_mpg "cash_register"
    read -r -p "Press Enter..."
}

# =============================================================================
# LOAN SHARK
# =============================================================================

visit_loan_shark() {
    run_clock 1
    clear_screen
    echo "--- Mo Money Loans (Unlicensed) ---"
    echo "\"We don't ask questions. We just expect repayment.\""
    echo "================================================"

    if $loan_shark_active && (( loan_principal > 0 )); then
        local days_out=$(( game_day - loan_taken_day ))
        printf " OUTSTANDING LOAN: \$%d\n" "$loan_principal"
        printf " Days outstanding: %d  |  Daily rate: %d%%\n" "$days_out" "$loan_interest_rate"
        printf " Interest accrued today: ~\$%d\n" "$(( loan_principal * loan_interest_rate / 100 ))"
        echo "================================================"
        echo " 1. Repay full loan"
        echo " 2. Make partial payment"
        echo " 3. Take out additional loan"
        echo " B. Back"
        read -r -p "Choice: " ls_choice

        case "${ls_choice,,}" in
            1)
                if (( cash >= loan_principal )); then
                    cash=$(( cash - loan_principal ))
                    echo -e "\e[1;32mLoan fully repaid.\e[0m They look almost disappointed."
                    loan_principal=0; loan_shark_active=false; loan_days_outstanding=0
                    play_sfx_mpg "cash_register"
                else
                    echo "Not enough cash to repay in full (\$${loan_principal} needed)."
                fi
                ;;
            2)
                read -r -p "How much to repay? " repay_amt
                if [[ "$repay_amt" =~ ^[1-9][0-9]*$ ]] && (( cash >= repay_amt && repay_amt <= loan_principal )); then
                    cash=$(( cash - repay_amt ))
                    loan_principal=$(( loan_principal - repay_amt ))
                    echo "Partial payment of \$${repay_amt} made. Remaining: \$${loan_principal}"
                    play_sfx_mpg "cash_register"
                    (( loan_principal <= 0 )) && loan_shark_active=false && echo "Loan cleared!"
                else echo "Invalid amount."; fi
                ;;
            3) _take_new_loan ;;
            b) return ;;
            *) echo "Invalid."; sleep 1 ;;
        esac
    else
        printf " No outstanding loans.\n"
        echo " Interest rate: ${loan_interest_rate}%% per day (compounding)"
        echo " Warning: Non-payment results in physical consequences."
        echo "================================================"
        echo " 1. Take out a loan"
        echo " B. Back"
        read -r -p "Choice: " ls_choice
        case "${ls_choice,,}" in
            1) _take_new_loan ;;
            b) return ;;
        esac
    fi
    read -r -p "Press Enter..."
}

_take_new_loan() {
    echo ""
    echo "Available loan amounts:"
    echo " 1. \$1,000   2. \$5,000   3. \$10,000   4. \$25,000   5. Custom"
    read -r -p "Choice: " loan_choice
    local loan_amount=0
    case "$loan_choice" in
        1) loan_amount=1000 ;;
        2) loan_amount=5000 ;;
        3) loan_amount=10000 ;;
        4) loan_amount=25000 ;;
        5)
            read -r -p "Enter custom amount: \$" custom_amt
            if [[ "$custom_amt" =~ ^[1-9][0-9]*$ ]]; then
                loan_amount=$custom_amt
            else echo "Invalid."; return; fi
            ;;
        *) echo "Invalid."; return ;;
    esac

    echo ""
    echo "Loan amount: \$${loan_amount}"
    echo "Daily interest: ${loan_interest_rate}% compounding"
    echo "At day 7, collectors may begin physical enforcement."
    read -r -p "Accept these terms? (y/n): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return

    loan_principal=$(( loan_principal + loan_amount ))
    cash=$(( cash + loan_amount ))
    loan_taken_day=$game_day
    loan_shark_active=true

    echo -e "\e[1;32mLoan of \$${loan_amount} disbursed.\e[0m Don't be late."
    play_sfx_mpg "cash_register"
}

# =============================================================================
# BLACK MARKET AUCTION
# =============================================================================

declare -A AUCTION_POOL=(
    ["Military Crate"]="8000:Stolen military equipment — weapons, ammo, body armor:item:3"
    ["Exotic Sports Car"]="25000:Untraceable foreign sports car, no plates:vehicle:5"
    ["Stinger Missile Launcher"]="50000:Anti-aircraft launcher. Do not ask where it came from:weapon:4"
    ["Police Radio Scanner"]="3000:Intercept police comms. Reduces ambush chance:item:3"
    ["Unmarked Van"]="12000:Ideal for heists and deliveries. No questions asked:vehicle:4"
    ["Diamond Necklace"]="15000:Hot off a jewelry store. Sell to a fence for profit:item:2"
    ["Hackers Toolkit"]="5000:Encrypted drives, exploit tools. Boosts tech-based heists:item:3"
    ["Forged Documents"]="4000:Business licenses, fake identities. Reduces heat generation:item:3"
    ["Armored Sedan"]="35000:Bulletproof. Reduces damage in all vehicle encounters:vehicle:5"
    ["Classified Intel Packet"]="20000:Government files. Sell to the highest bidder:item:3"
)

refresh_auction() {
    (( game_day - auction_last_refresh < 5 && ${#auction_items[@]} > 0 )) && return
    auction_last_refresh=$game_day
    auction_items=()

    local -a pool_keys=("${!AUCTION_POOL[@]}")
    local num=$(( RANDOM % 3 + 3 ))
    local -a used=()
    local added=0 attempts=0

    while (( added < num && attempts < 30 )); do
        ((attempts++))
        local idx=$(( RANDOM % ${#pool_keys[@]} ))
        local item="${pool_keys[$idx]}"
        local already=false
        for u in "${used[@]}"; do [[ "$u" == "$item" ]] && already=true && break; done
        $already && continue

        local def="${AUCTION_POOL[$item]}"
        local base_price desc type duration
        IFS=':' read -r base_price desc type duration <<< "$def"

        local expires=$(( game_day + duration ))
        local random_markup=$(( RANDOM % 30 - 10 ))
        local listed_price=$(( base_price + base_price * random_markup / 100 ))
        (( listed_price < 100 )) && listed_price=100

        auction_items["$item"]="${listed_price}:${desc}:${type}:${expires}"
        used+=("$item"); ((added++))
    done
}

show_black_market_auction() {
    run_clock 1
    refresh_auction

    while true; do
        clear_screen
        echo "--- Black Market Auction House ---"
        echo "  Anonymous bids only. All sales final."
        printf "  Your Cash: \$%d\n" "$cash"
        echo "=================================================="

        local i=1
        local -a auction_keys=()
        for item_name in "${!auction_items[@]}"; do
            local data="${auction_items[$item_name]}"
            local price desc type expires
            IFS=':' read -r price desc type expires <<< "$data"

            local time_left=$(( expires - game_day ))
            (( time_left < 0 )) && time_left=0

            local type_color="\e[0m"
            case "$type" in
                weapon) type_color="\e[1;31m" ;;
                vehicle) type_color="\e[1;34m" ;;
                item) type_color="\e[1;33m" ;;
            esac

            printf " %2d. %-28s ${type_color}[%-7s]\e[0m \$%-8d Expires: %d day(s)\n" \
                "$i" "$item_name" "$type" "$price" "$time_left"
            echo "     \"${desc}\""
            echo ""
            auction_keys+=("$item_name")
            ((i++))
        done

        echo "=================================================="
        echo " R. Refresh listings    B. Back to main"
        echo "=================================================="
        read -r -p "Enter item number to bid, or R/B: " auc_choice

        case "${auc_choice,,}" in
            b) return ;;
            r)
                auction_last_refresh=0
                refresh_auction
                echo "Refreshed."; sleep 1
                ;;
            *)
                if [[ "$auc_choice" =~ ^[0-9]+$ ]] && (( auc_choice >= 1 && auc_choice <= ${#auction_keys[@]} )); then
                    local chosen_item="${auction_keys[$((auc_choice-1))]}"
                    purchase_auction_item "$chosen_item"
                else
                    echo "Invalid."; sleep 1
                fi
                ;;
        esac
    done
}

purchase_auction_item() {
    local item_name="$1"
    local data="${auction_items[$item_name]}"
    local price desc type expires
    IFS=':' read -r price desc type expires <<< "$data"

    clear_screen
    echo "--- Place Bid: ${item_name} ---"
    echo "================================================"
    printf " Description: %s\n" "$desc"
    printf " Type:        %s\n" "$type"
    printf " Listed price: \$%d\n" "$price"
    printf " Expires:     Day %d (in %d day(s))\n" "$expires" "$(( expires - game_day ))"
    echo "================================================"
    printf " Your cash:   \$%d\n" "$cash"
    echo ""
    echo " 1. Buy at listed price"
    echo " 2. Negotiate (charisma-based, may get a discount)"
    echo " B. Back"
    read -r -p "Choice: " bid_choice

    local final_price=$price

    case "${bid_choice,,}" in
        1) ;;  # use listed price
        2)
            local charisma=${skills[charisma]:-1}
            local nego_chance=$(( 20 + charisma * 8 ))
            (( nego_chance > 70 )) && nego_chance=70
            echo "You try to negotiate a better deal..."
            sleep 1
            if (( RANDOM % 100 < nego_chance )); then
                local discount=$(( RANDOM % 15 + 5 ))
                final_price=$(( price - price * discount / 100 ))
                echo -e "\e[1;32mThey agreed to a ${discount}% discount!\e[0m New price: \$${final_price}"
            else
                echo "They didn't budge. Paying listed price."
            fi
            ;;
        b) return ;;
        *) echo "Invalid."; return ;;
    esac

    if (( cash < final_price )); then
        echo "Not enough cash (\$${final_price} needed)."; read -r -p "Press Enter..."; return
    fi

    read -r -p "Confirm purchase for \$${final_price}? (y/n): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return

    cash=$(( cash - final_price ))
    play_sfx_mpg "cash_register"

    case "$type" in
        vehicle)
            owned_vehicles+=("$item_name")
            echo -e "\e[1;32mVehicle added to your garage: ${item_name}\e[0m"
            ;;
        item)
            items+=("$item_name")
            echo -e "\e[1;32mItem added to your inventory: ${item_name}\e[0m"
            ;;
        weapon)
            guns+=("$item_name")
            echo -e "\e[1;32mWeapon added to your arsenal: ${item_name}\e[0m"
            ;;
    esac

    unset "auction_items[$item_name]"
    award_respect $(( RANDOM % 15 + 5 ))
    read -r -p "Press Enter..."
}

# =============================================================================
# ECONOMY SAVE / LOAD HOOKS
# =============================================================================

economy_save_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"

    # Save stock portfolio
    : > "$save_path/stocks_portfolio.sav"
    for ticker in "${!stock_portfolio[@]}"; do
        printf "%s@@@%s\n" "$ticker" "${stock_portfolio[$ticker]}" >> "$save_path/stocks_portfolio.sav"
    done

    # Save stock prices
    : > "$save_path/stocks_prices.sav"
    for ticker in "${!stock_prices[@]}"; do
        printf "%s@@@%s\n" "$ticker" "${stock_prices[$ticker]}" >> "$save_path/stocks_prices.sav"
    done

    # Save stock history
    : > "$save_path/stocks_history.sav"
    for ticker in "${!stock_history[@]}"; do
        printf "%s@@@%s\n" "$ticker" "${stock_history[$ticker]}" >> "$save_path/stocks_history.sav"
    done

    # Save insider tips
    : > "$save_path/insider_tips.sav"
    for ticker in "${!stock_insider_tips[@]}"; do
        printf "%s@@@%s\n" "$ticker" "${stock_insider_tips[$ticker]}" >> "$save_path/insider_tips.sav"
    done

    # Save loan state
    printf "principal@@@%d\nrate@@@%d\ntaken_day@@@%d\nactive@@@%s\n" \
        "$loan_principal" "$loan_interest_rate" "$loan_taken_day" "$loan_shark_active" \
        > "$save_path/loan_shark.sav"

    # Save launder jobs
    : > "$save_path/laundering.sav"
    for prop in "${!laundering_jobs[@]}"; do
        printf "%s@@@%s\n" "$prop" "${laundering_jobs[$prop]}" >> "$save_path/laundering.sav"
    done

    printf "total@@@%d\n" "$total_laundered" >> "$save_path/laundering.sav"
}

economy_load_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    stock_portfolio=(); stock_prices=(); stock_history=(); stock_insider_tips=()
    laundering_jobs=(); loan_principal=0; loan_shark_active=false; loan_taken_day=0

    _load_assoc_sav() {
        local file="$1"
        local -n _arr="$2"
        _arr=()
        [[ ! -f "$file" ]] && return
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            local k="${line%%@@@*}" v="${line#*@@@}"
            _arr["$k"]="$v"
        done < "$file"
    }

    _load_assoc_sav "$save_path/stocks_portfolio.sav" stock_portfolio
    _load_assoc_sav "$save_path/stocks_prices.sav" stock_prices
    _load_assoc_sav "$save_path/stocks_history.sav" stock_history
    _load_assoc_sav "$save_path/insider_tips.sav" stock_insider_tips

    if [[ -f "$save_path/loan_shark.sav" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            local k="${line%%@@@*}" v="${line#*@@@}"
            case "$k" in
                principal) loan_principal="$v" ;;
                rate) loan_interest_rate="$v" ;;
                taken_day) loan_taken_day="$v" ;;
                active) loan_shark_active="$v" ;;
            esac
        done < "$save_path/loan_shark.sav"
    fi

    if [[ -f "$save_path/laundering.sav" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            local k="${line%%@@@*}" v="${line#*@@@}"
            if [[ "$k" == "total" ]]; then
                total_laundered="$v"
            else
                laundering_jobs["$k"]="$v"
            fi
        done < "$save_path/laundering.sav"
    fi

    init_stock_prices
}

# =============================================================================
# MASTER ECONOMY MENU — call this from the main game loop
# =============================================================================

show_economy_menu() {
    tick_stock_market
    while true; do
        clear_screen
        echo "--- Underworld Economy ---"
        echo "================================================"
        echo " 1. Stock Market Terminal"
        echo " 2. Money Laundering Operations"
        echo " 3. Loan Shark"
        echo " 4. Black Market Auction House"
        echo " B. Back to Main Menu"
        echo "================================================"
        if $loan_shark_active && (( loan_principal > 0 )); then
            echo -e " \e[1;31mOUTSTANDING LOAN: \$${loan_principal}\e[0m"
        fi
        if (( ${#laundering_jobs[@]} > 0 )); then
            echo -e " \e[1;32mActive launder jobs: ${#laundering_jobs[@]}\e[0m"
        fi
        echo "================================================"
        read -r -p "Choice: " eco_choice
        case "${eco_choice,,}" in
            1) show_stock_market ;;
            2) money_laundering_menu ;;
            3) visit_loan_shark ;;
            4) show_black_market_auction ;;
            b) return ;;
            *) echo "Invalid."; sleep 1 ;;
        esac
    done
}

# Announce plugin loaded
echo "[Plugin] Underworld Stock Market & Economy loaded."
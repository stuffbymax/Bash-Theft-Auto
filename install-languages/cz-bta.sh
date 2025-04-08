#!/bin/bash
#Překlad byl vytvořen umělou inteligencí
#Bash-Theft-Auto hudba a zvukové efekty © 2024 od stuffbymax - Martin Petik je licencován pod CC BY 4.0
#https://creativecommons.org/licenses/by/4.0/
#ver 2.0.2
#!/bin/bash
BASEDIR="$(dirname "$(realpath "$0")")"
# --- 0. Globální proměnné ---
player_name=""
location=""
cash=0
health=0
declare -a guns
declare -a items
declare -A drugs
declare -A skills
body_armor_equipped=false
SAVE_DIR="saves"
declare -A gun_attributes

gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

# --- Nastavení zvukových efektů ---
sfx_dir="sfx"  # Adresář pro zvukové efekty

#mpg123
# Funkce pro přehrávání zvukových efektů (pomocí mpg123)
play_sfx_mpg() {
	local sound_file="$sfx_dir/$1.mp3"
	if [[ -f "$sound_file" ]]; then
		mpg123 -q "$sound_file" &
		return 0  # Indikuje úspěch
	else
		echo "Zvukový soubor '$sound_file' nebyl nalezen!"
		return 1  # Indikuje neúspěch
	fi
}

# --- 1. Načítání pluginů ---
plugin_dir="plugins"

if [[ -d "$plugin_dir" ]]; then
	while IFS= read -r -d $'\0' plugin; do
		[[ -f "$plugin" ]] && source "$plugin"
	done < <(find "$plugin_dir" -maxdepth 1 -name "*.sh" -print0)
else
	echo "Varování: Adresář pluginů '$plugin_dir' nebyl nalezen."
fi

# --- 3. Funkce ---

# Vyčistí obrazovku a zobrazí informace o hře
clear_screen() {
clear
printf "\e[93m=========================================\e[0m\n"
printf "\e[1;43m|        Bash theaft auto               |\e[0m\n"
printf "\e[93m=========================================\e[0m\n"
printf "Hráč: %s   Lokace: %s\n" "$player_name" "$location"
printf "Peníze: %d dolarů      Zdraví: %d%%\n" "$cash" "$health"
printf "\e[1;34m=========================================\e[0m\n"
printf "\e[1;44m|        vytvořeno stuffbymax             |\e[0m\n"
printf "\e[1;34m=========================================\e[0m\n"
}

# --- O hře ---
about_music_sfx() {
	clear_screen
	echo -e "-----------------------------------------"
	echo "|  O hudbě a zvukových efektech         |"
	echo "-----------------------------------------"
	echo ""
	echo "Hudba a některé zvukové efekty v této hře"
	echo "byly vytvořeny stuffbymax - Martin Petik."
	echo ""
	echo "Jsou licencovány pod Creative"
	echo "Commons Attribution 4.0 International"
	echo "(CC BY 4.0) licencí:"
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "To znamená, že je můžete volně používat ve"
	echo "svých vlastních projektech, i komerčně,"
	echo "pokud uvedete odpovídající kredit."
	echo ""
	echo "Prosím, uveďte hudbu a zvukové"
	echo "efekty s následujícím prohlášením:"
	echo ""
	echo "'Hudba a zvukové efekty © 2024 od"
	echo "stuffbymax - Martin Petik, licencováno pod"
	echo "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)'"
	echo ""
	echo "Pro více informací o stuffbymax -"
	echo "Martin Petik a mé práci, navštivte:"
	echo "https://stuffbymax.me/ nebo https://stuffbymax.me/wiki-blogs"
	echo ""
	echo "-----------------------------------------"
	echo "|  Licence kódu                          |"
	echo "-----------------------------------------"
	echo ""
	echo "Kód pro tuto hru je licencován pod licencí MIT."
	echo "Copyright (c) 2024 stuffbymax"
	echo "Můžete jej volně používat, upravovat a distribuovat"
	echo "s řádným uvedením autora."
	echo ""
	echo "Pro plné znění licence navštivte:"
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE"
	echo ""
	echo "Děkujeme za hraní!"
	read -r -p "Stiskněte Enter pro návrat do hlavního menu..."
}

# Funkce pro kontrolu, zda je hráč naživu
check_health() {
	if (( health <= 0 )); then
		echo "Nemáte žádné zdraví! Přeprava do nemocnice..."
		read -r -p "Stiskněte Enter pro pokračování..."
		hospitalize_player
	fi
}

# Funkce pro cestování na nové místo
travel_to() {
	local travel_cost="$1"
	local new_location="$2"

	if (( cash >= travel_cost )); then
		echo "Cestování do $new_location..."
		play_sfx_mpg "air"

		# --- Animace letecké dopravy (Volání pluginu) ---
		air_travel_animation # Volání funkce v animation.sh
		# --- Konec animace letecké dopravy ---

		cash=$((cash - travel_cost))
		# Odstraňte výzvu stisknutí Enter zde, je zbytečná s animací

		location="$new_location"
		clear_screen
		echo "Dorazili jste do $new_location."
	else
		echo "Nedostatek peněz na cestu do $new_location."
		read -r -p "Stiskněte Enter pro pokračování..."
		clear_screen
	fi
}

# Funkce pro nákup zbraní
buy_guns() {
	local gun_choice
	clear_screen
	echo "Obchod se zbraněmi - Vyberte zbraň k nákupu:"
	echo "1. Pistole (100$)"
	echo "2. Brokovnice (250$)"
	echo "3. SMG (500$)"
	echo "4. Puška (750$)"
	echo "5. Sniper (1000$)"
	echo "6. Zpět do hlavního menu"
	read -r -p "Zadejte svou volbu (číslo): " gun_choice

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo z menu."
		read -r -p "Stiskněte Enter pro pokračování..."
		return
	}

	case "$gun_choice" in
		1) buy_item "Pistole" 100;;
		2) buy_item "Brokovnice" 250;;
		3) buy_item "SMG" 500;;
		4) buy_item "Puška" 750;;
		5) buy_item "Sniper" 1000;;
		6) clear_screen;;
		*) echo "Neplatná volba.";;
	esac
}

# Pomocná funkce pro nákup položek
buy_item() {
	local item_name="$1"
	local item_cost="$2"
	play_sfx_mpg "cash_register"
	buy_animation

	if (( cash >= item_cost )); then
		cash=$((cash - item_cost))
		guns+=("$item_name")
		echo "Koupili jste si $item_name."
		read -r -p "Stiskněte Enter pro pokračování..."
	else
		echo "Nedostatek peněz na koupi $item_name."
		read -r -p "Stiskněte Enter pro pokračování..."
	fi
}

# Funkce pro zobrazení inventáře
show_inventory() {
	clear_screen
	echo "Váš inventář:"
	printf "Peníze: %d dolarů\n" "$cash"
	printf "Zdraví: %d%%\n" "$health"
	printf "Zbraně: %s\n" "${guns[*]}"
	printf "Předměty: %s\n" "${items[*]}"
	echo "Drogy: "
	local IFS=$'\n'
	for drug in "${!drugs[@]}"; do
		printf "  - %s: %s\n" "$drug" "${drugs[$drug]}"
	done
	IFS=$' \t\n' # Obnovení IFS

	echo "Dovednosti:"
	local IFS=$'\n'
	for skill in "${!skills[@]}"; do
		printf "  - %s: %s\n" "$skill" "${skills[$skill]}"
	done
	IFS=$' \t\n' # Obnovení IFS
	read -r -p "Stiskněte Enter pro návrat do hlavního menu."
}

# Funkce pro práci (zjednodušená logika)
work_job() {
	local job_type="$1"
	local earnings
	local min_earnings max_earnings
	local driving_skill=$((skills["driving"] * 5)) #Příklad použití dovedností

	case "$location" in
		"Los Santos") min_earnings=20; max_earnings=$((60 + driving_skill));;
		"San Fierro") min_earnings=25; max_earnings=$((70 + driving_skill));;
		"Las Venturas") min_earnings=30; max_earnings=$((90 + driving_skill));;
		"Vice City") min_earnings=15; max_earnings=$((50 + driving_skill));;
		"Liberty City") min_earnings=35; max_earnings=$((100 + driving_skill));;
		*) min_earnings=10; max_earnings=$((40 + driving_skill));; # Výchozí hodnoty
	esac

	case "$job_type" in
		"taxi")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))
			play_sfx_mpg "taxi"
			working_animation
			;;
		"delivery")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 10))
			play_sfx_mpg "taxi"
			working_animation
			;;
		"mechanic")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 20))
			play_sfx_mpg "mechanic"
			working_animation
			;;
		"security")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 30))
			play_sfx_mpg "security"
			working_animation
			;;
		"performer")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings - 20))
			play_sfx_mpg "street_performer"
			working_animation
			;;
		*) echo "Neplatná práce"; return;;
	esac

	echo "Pracujete jako $job_type řidič v $location..."
	read -r -p "Stiskněte Enter pro pokračování..."

	cash=$((cash + earnings))
	clear_screen
	printf "Vydělali jste %d dolarů. Nyní máte %d dolarů.\n" "$earnings" "$cash"
	read -r -p "Stiskněte Enter pro pokračování..."
}

# Funkce pro pouliční závody (samostatná funkce)
street_race() {
	working_animation
	echo "Účastníte se pouličního závodu v $location..."
	read -r -p "Stiskněte Enter pro pokračování..."
	local winnings
	local damage
	local driving_skill=$((skills["driving"] * 5))
	local win_chance=$((50 + driving_skill)) # Ovlivňuje šanci na výhru

	if (( RANDOM % 100 < win_chance )); then
		winnings=$((RANDOM % 201 + 100))
		cash=$((cash + winnings))
		damage=$((RANDOM % 21 + 10))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaše neprůstřelná vesta snížila poškození!"
			body_armor_equipped=false
		fi
		health=$((health - damage))
		check_health
		clear_screen
		printf "Vyhráli jste pouliční závod a získali %d dolarů, ale ztratili %d%% zdraví. Nyní máte %d dolarů a %d%% zdraví.\n" "$winnings" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Přehrání zvuku výhry
		read -r -p "Stiskněte Enter pro pokračování..."
	else
		damage=$((RANDOM % 41 + 20))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaše neprůstřelná vesta snížila poškození!"
			body_armor_equipped=false
		fi
		health=$((health - damage))
		check_health
		clear_screen
		printf "Prohráli jste pouliční závod a utrpěli %d%% poškození. Nyní máte %d%% zdraví.\n" "$damage" "$health"
		play_sfx_mpg "lose" # Přehrání zvuku prohry
		read -r -p "Stiskněte Enter pro pokračování..."
	fi
}

# Funkce pro použití zbraní pro práci - aktuálně se nepoužívá v pracích, ale ponechána pro potenciální budoucí použití.
use_guns() {
	if [[ " ${guns[*]} " == *" $1 "* ]]; then
		echo "Použili jste svůj $1 pro tuto práci."
		play_sfx_mpg "gun_shot"
		read -r -p "Stiskněte Enter pro pokračování..."
	else
		echo "Nemáte $1. Práce selhala."
		read -r -p "Stiskněte Enter pro pokračování..."
	fi
}

# Funkce pro návštěvu nemocnice
visit_hospital() {
	local hospital_choice
	clear_screen
	echo "Nemocniční služby:"
	echo "1. Základní ošetření (50$) - Plné uzdravení"
	echo "2. Pokročilé ošetření (100$) - Plné uzdravení + 10% bonus zdraví"
	echo "3. Koupit lékárničku (30$) - Uzdravení 25% zdraví"
	echo "4. Koupit neprůstřelnou vestu (75$) - Snížení poškození o 50% v příštím střetu"
	echo "5. Zpět do hlavního menu"
	read -r -p "Zadejte svou volbu (číslo): " hospital_choice

	[[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo z menu."
		read -r -p "Stiskněte Enter pro pokračování..."
		return
	}

	case "$hospital_choice" in
		1) buy_hospital_item 50 "basic_treatment";;
		2) buy_hospital_item 100 "advanced_treatment";;
		3) buy_hospital_item 30 "health_pack";;
		4) buy_hospital_item 75 "body_armor";;
		5) clear_screen;;
		*) echo "Neplatná volba.";;
	esac
}

# Pomocná funkce pro nákup nemocničních položek
buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2"

	if (( cash >= item_cost )); then
		cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment")
				health=100
				echo "Obdrželi jste základní ošetření a jste plně uzdraveni."
				play_sfx_mpg "heal" # Přehrání zvuku uzdravení
				read -r -p "Stiskněte Enter pro pokračování..."
				;;
			"advanced_treatment")
				health=$((health + 10))
				(( health > 100 )) && health=100
				echo "Obdrželi jste pokročilé ošetření a jste plně uzdraveni s bonusem zdraví."
				play_sfx_mpg "heal" # Přehrání zvuku uzdravení
				read -r -p "Stiskněte Enter pro pokračování..."
				;;
			"health_pack")
				items+=("Lékárnička")
				echo "Koupili jste si lékárničku."
				play_sfx_mpg "item_buy" # Přehrání zvuku nákupu položky
				read -r -p "Stiskněte Enter pro pokračování..."
				;;
			"body_armor")
				body_armor_equipped=true
				echo "Koupili jste si neprůstřelnou vestu."
				play_sfx_mpg "item_buy" # Přehrání zvuku nákupu položky
				read -r -p "Stiskněte Enter pro pokračování..."
				;;
		esac
	else
		echo "Nedostatek peněz na $item_type."
		read -r -p "Stiskněte Enter pro pokračování..."
	fi
}

# Funkce pro vykradení obchodu
rob_store() {
	robbing_animation
	echo "Pokouší se vykrást obchod v $location..."

	local stealth_skill=$((skills["stealth"] * 5)) # Základní dovednost plížení
	local gun_bonus=0 # Inicializace bonusu zbraně

	if (( ${#guns[@]} > 0 )); then
		echo "Chcete použít zbraň? (a/n)"
		read -r use_gun

	if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then
			echo "Kterou zbraň chcete použít? (Zadejte název zbraně)"
			echo "Dostupné zbraně: ${guns[*]}"
			read -r chosen_gun

			# Kontrola, zda hráč má danou zbraň
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "Použili jste $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Přehrání zvuku výstřelu

				# --- Aplikace bonusu zbraně ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}" # Extrahování řetězce atributů
					gun_bonus=$success_bonus # Získání bonusu za úspěch
					stealth_skill=$((stealth_skill + gun_bonus)) # Aplikace bonusu
					echo "$chosen_gun vám dává +${gun_bonus}% šanci na úspěch."
				else
					echo "Pro $chosen_gun nejsou definovány žádné atributy (Toto je chyba skriptu)."
				fi
				# --- Konec bonusu zbraně ---
			else
				echo "Nemáte tuto zbraň!"
			fi
		else
			echo "Pokračování bez zbraně."
		fi
	else
		echo "Nemáte žádné zbraně!"
	fi

	read -r -p "Stiskněte Enter pro pokračování..."

	local loot
	local damage
	local fine
	if (( RANDOM % 100 < stealth_skill )); then
		loot=$((RANDOM % 201 + 100))
		cash=$((cash + loot))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaše neprůstřelná vesta snížila poškození!"
			body_armor_equipped=false
		fi

		damage=$((RANDOM % 31 + 10))
		health=$((health - damage))
		check_health
		clear_screen
		printf "Úspěšně jste vykradli obchod a získali %d dolarů, ale ztratili %d%% zdraví. Nyní máte %d dolarů a %d%% zdraví.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "cash_register"
		read -r -p "Stiskněte Enter pro pokračování..."
	else
		fine=$((RANDOM % 51 + 25))
		cash=$((cash - fine))
		clear_screen
		printf "Byli jste chyceni a pokutováni %d dolary. Nyní máte %d dolarů.\n" "$fine" "$cash"
		play_sfx_mpg "lose"   # Přehrání zvuku prohry
		read -r -p "Stiskněte Enter pro pokračování..."
	fi
}

# Funkce pro účast na přepadení
heist() {
	heist_animation
	echo "Plánování přepadení v $location..."

	local stealth_skill=$((skills["stealth"] * 5)) # Základní dovednost plížení
	local gun_bonus=0 # Inicializace bonusu zbraně

	if (( ${#guns[@]} > 0 )); then
		echo "Chcete použít zbraň? (a/n)"
		read -r use_gun

		if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then
			echo "Kterou zbraň chcete použít? (Zadejte název zbraně)"
			echo "Dostupné zbraně: ${guns[*]}"
			read -r chosen_gun
			# Kontrola, zda hráč má danou zbraň
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "Použili jste $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Přehrání zvuku výstřelu

				# --- Logika bonusu zbraně ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
					gun_bonus=$success_bonus
					stealth_skill=$((stealth_skill + gun_bonus))
					echo "$chosen_gun vám dává +${gun_bonus}% šanci na úspěch."
				else
					echo "Pro $chosen_gun nejsou definovány žádné atributy (Toto je chyba skriptu)."
				fi
				# --- Konec logiky bonusu zbraně ---

			else
				echo "Nemáte tuto zbraň!"
			fi
		else
			echo "Pokračování bez zbraně."
		fi
	else
		echo "Nemáte žádné zbraně!"
	fi

	read -r -p "Stiskněte Enter pro pokračování..."

	local loot
	local damage
	local fine
	if (( RANDOM % 100 < stealth_skill )); then
		loot=$((RANDOM % 501 + 200))
		cash=$((cash + loot))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaše neprůstřelná vesta snížila poškození!"
			body_armor_equipped=false
		fi

		damage=$((RANDOM % 51 + 20))
		health=$((health - damage))
		check_health
		clear_screen
		printf "Přepadení bylo úspěšné! Získali jste %d dolarů, ale ztratili %d%% zdraví. Nyní máte %d dolarů a %d%% zdraví.\n" "$loot" "$damage" "$cash" "$health"
		read -r -p "Stiskněte Enter pro pokračování..."
	else
		fine=$((RANDOM % 101 + 50))
		cash=$((cash - fine))

		clear_screen
		printf "Přepadení selhalo a byli jste chyceni, ztratili jste %d dolarů. Nyní máte %d dolarů.\n" "$fine" "$cash"
		play_sfx_mpg "lose"  # Přehrání zvuku prohry
		read -r -p "Stiskněte Enter pro pokračování..."
	fi
}

# Funkce pro gangové války
gang_war() {
	# Kontrola, zda hráč má nějaké zbraně
	if (( ${#guns[@]} == 0 )); then
		echo "Nemůžete začít gangovou válku bez zbraně!"
		read -r -p "Stiskněte Enter pro pokračování..."
		return
	fi

	gang_war_animation
	echo "Začíná gangová válka v $location..."

	local strength_skill=$((skills["strength"] * 5)) # Základní dovednost síly
	local gun_bonus=0 # Inicializace bonusu zbraně

	if (( ${#guns[@]} > 0 )); then
		echo "Chcete použít zbraň? (a/n)"
		read -r use_gun

		if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then
			echo "Kterou zbraň chcete použít? (Zadejte název zbraně)"
			echo "Dostupné zbraně: ${guns[*]}"
			read -r chosen_gun

			# Kontrola, zda hráč má danou zbraň
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "Použili jste $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Přehrání zvuku výstřelu

				# --- Logika bonusu zbraně ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
					gun_bonus=$success_bonus
					strength_skill=$((strength_skill + gun_bonus)) # Použití strength_skill zde
					echo "$chosen_gun vám dává +${gun_bonus}% šanci na úspěch."
				else
					echo "Pro $chosen_gun nejsou definovány žádné atributy (Toto je chyba skriptu)."
				fi
				# --- Konec logiky bonusu zbraně ---

			else
				echo "Nemáte tuto zbraň!"
			fi
		else
			echo "Pokračování bez zbraně."
		fi
	else
		echo "Nemáte žádné zbraně!"
	fi

	read -r -p "Stiskněte Enter pro pokračování..."

	local loot
	local damage
	local fine

	if (( RANDOM % 100 < strength_skill )); then
		loot=$((RANDOM % 301 + 100))
		cash=$((cash + loot))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaše neprůstřelná vesta snížila poškození!"
			body_armor_equipped=false
		fi

		damage=$((RANDOM % 51 + 30))
		health=$((health - damage))
		check_health
		clear_screen
		printf "Vyhráli jste gangovou válku a získali %d dolarů, ale ztratili %d%% zdraví. Nyní máte %d dolarů a %d%% zdraví.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Přehrání zvuku gangové války
		read -r -p "Stiskněte Enter pro pokračování..."
	else
		fine=$((RANDOM % 151 + 50))
		cash=$((cash - fine))
		damage=$((RANDOM % 41 + 20))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaše neprůstřelná vesta snížila poškození!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Prohráli jste gangovou válku, byli jste pokutováni %d dolary a ztratili %d%% zdraví. Nyní máte %d dolarů a %d%% zdraví.\n" "$fine" "$damage" "$cash" "$health"
		play_sfx_mpg "lose"  # Přehrání zvuku prohry
		read -r -p "Stiskněte Enter pro pokračování..."
	fi
}

# Funkce pro krádež auta
carjack() {
	# Kontrola, zda hráč má nějaké zbraně
	if (( ${#guns[@]} == 0 )); then
		# Upozornění hráče, že nemá zbraň
		echo "Nemáte zbraň, takže se budete muset spolehnout na své dovednosti. To ztíží krádež auta."
		read -r -p "Stiskněte Enter pro pokračování..."
		success_chance=$((success_chance - 20))  # Snížení šance na úspěch, když není k dispozici zbraň
	fi

	# Kontrola, zda se hráč rozhodl použít zbraň
	if (( ${#guns[@]} > 0 )); then
		# Dotaz na hráče, zda chce použít zbraň
		echo "Chcete použít zbraň? (a/n)"
		read -r use_gun

		if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then
			# Výpis dostupných zbraní
			echo "Kterou zbraň chcete použít? (Zadejte název zbraně)"
			echo "Dostupné zbraně: ${guns[*]}"
			read -r chosen_gun

			# Kontrola, zda hráč má vybranou zbraň
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "Použili jste $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Přehrání zvuku výstřelu
				local gun_bonus=0 # Inicializace bonusu zbraně zde uvnitř bloku if $gun_found

				# --- Logika bonusu zbraně ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
					gun_bonus=$success_bonus
					success_chance=$((success_chance + gun_bonus)) # Aplikace na success_chance
					echo "$chosen_gun vám dává +${gun_bonus}% šanci na úspěch."
				else
					echo "Pro $chosen_gun nejsou definovány žádné atributy (Toto je chyba skriptu)."
				fi
				# --- Konec logiky bonusu zbraně ---

			else
				echo "Nemáte tuto zbraň!"
				# Pokračování bez zbraně, pokud vybraná zbraň neexistuje
				echo "Pokračování bez zbraně."
				success_chance=$((success_chance - 20))  # Snížení šance na úspěch bez zbraně (-20)
			fi
		else
			# Pokud se hráč rozhodne nepoužít zbraň, pokračování bez ní
			echo "Pokračování bez zbraně."
			success_chance=$((success_chance - 20))  # Snížení šance na úspěch bez zbraně (-20)
		fi
	fi

	# Spuštění animace krádeže auta po rozhodnutí
	carjacking_animation
	echo "Pokouší se ukrást vozidlo v $location..."
	read -r -p "Stiskněte Enter pro pokračování..."

	local loot
	local damage
	local fine
	local driving_skill=$((skills["driving"] * 5))
	local stealth_skill=$((skills["stealth"] * 5))
	success_chance=$((driving_skill + stealth_skill + success_chance))

	# Nyní vypočítat šanci na úspěch po zvážení zbraně
	if (( RANDOM % 100 < success_chance )); then
		loot=$((RANDOM % 201 + 50))
		cash=$((cash + loot))

		damage=$((RANDOM % 21 + 10))

		if [[ "$body_armor_equipped" == true ]]; then
			damage=$((damage / 2))
			echo "Vaše neprůstřelná vesta snížila poškození!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Úspěšně jste ukradli vozidlo a získali %d dolarů, ale ztratili %d%% zdraví.\nNyní máte %d dolarů a %d%% zdraví.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "car_start"  # Přehrání zvuku krádeže auta
		read -r -p "Stiskněte Enter pro pokračování..."
	else
		fine=$((RANDOM % 76 + 25))
		cash=$((cash - fine))
		clear_screen
		printf "Byli jste chyceni a pokutováni %d dolary. Nyní máte %d dolarů.\n" "$fine" "$cash"
		play_sfx_mpg "lose"  # Přehrání zvuku prohry
		read -r -p "Stiskněte Enter pro pokračování..."
	fi
}

# Funkce pro ošetření v nemocnici po smrti
hospitalize_player() {
	clear_screen
	echo "Byli jste hospitalizováni a jste léčeni..."
	read -r -p "Stiskněte Enter pro pokračování..."
	health=100
	clear_screen
	echo "Jste plně uzdraveni, ale ztratili jste 200 dolarů za léčbu."
	cash=$((cash - 200))
	(( cash < 0 )) && cash=0
	read -r -p "Stiskněte Enter pro pokračování..."
	clear_screen
}

# Funkce pro najmutí prostitutky
hire_hooker() {
	echo "Hledáte prostitutku v $location..."
	read -r -p "Stiskněte Enter pro pokračování..."
	local hooker_cost
	local health_gain
	local charisma_skill=$(( skills["charisma"] * 2 ))  # Ovlivňuje cenu
	# Zajištění, že charisma_skill je v rozumném rozmezí
	(( charisma_skill > 99 )) && charisma_skill=99
	# Zajištění, že rozsah RANDOM je pozitivní
	local min_cost=$(( 50 - charisma_skill ))
	local max_cost=$(( 101 - charisma_skill ))
	(( min_cost < 1 )) && min_cost=1
	(( max_cost <= min_cost )) && max_cost=$(( min_cost + 10 ))  # Zajištění platného rozsahu
	hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	# Zajištění minimální ceny
	(( hooker_cost < 10 )) && hooker_cost=10
	health_gain=$(( RANDOM % 21 + 10 ))
	if (( cash >= hooker_cost )); then
	cash=$(( cash - hooker_cost ))
	health=$(( health + health_gain ))
	(( health > 100 )) && health=100
	clear_screen
	printf "Najali jste si prostitutku za %d dolarů a získali %d%% zdraví.\nNyní máte %d dolarů a %d%% zdraví.\n" \
	"$hooker_cost" "$health_gain" "$cash" "$health"
	play_sfx_mpg "hooker"  # Přehrání zvuku prostitutky
	read -r -p "Stiskněte Enter pro pokračování..."
else
	clear_screen
	echo "Nedostatek peněz na najmutí prostitutky."
	read -r -p "Stiskněte Enter pro pokračování..."
	fi

clear_screen
}


# Centralizovaná funkce transakce drog
drug_transaction() {
	local action="$1" # "buy" nebo "sell"
	local drug_name="$2"
	local drug_price="$3"
	local drug_amount="$4"
	local cost income selling_price
	local drug_dealer_skill=$((skills["drug_dealer"]))

	if [[ "$action" == "buy" ]]; then
		cost=$((drug_price * drug_amount))
		if (( cash >= cost )); then
			drug_transaction_animation
			cash=$((cash - cost))
			drugs["$drug_name"]=$((drugs["$drug_name"] + drug_amount))
			printf "Koupili jste %s jednotek %s.\n" "$drug_amount" "$drug_name"
			play_sfx_mpg "cash_register"
			return 0
		else
			echo "Nedostatek peněz na koupi $drug_name."
			return 1
		fi
	elif [[ "$action" == "sell" ]]; then
		if [[ -v "drugs[$drug_name]" ]] && (( drugs["$drug_name"] >= drug_amount )); then
			drug_transaction_animation

			# Úprava prodejní ceny na základě dovednosti
			local price_modifier=$((drug_dealer_skill * 2)) # Příklad: 2% nárůst za bod dovednosti
			local adjusted_price=$((drug_price + (drug_price * price_modifier / 100)))

			income=$((adjusted_price * drug_amount))
			cash=$((cash + income))
			drugs["$drug_name"]=$((drugs["$drug_name"] - drug_amount))

			printf "Prodali jste %s jednotek %s za %d dolarů (upraveno podle vašich dovedností prodeje drog).\n" "$drug_amount" "$drug_name" "$income"
			play_sfx_mpg "cash_register"
			# Zvýšení dovednosti prodeje drog
			skills["drug_dealer"]=$((drug_dealer_skill + 1)) # Jednoduché zvýšení
			echo "Vaše dovednost prodeje drog se zvýšila!"
			return 0
		else
			echo "Nedostatek $drug_name k prodeji."
			return 1
		fi
	else
		echo "Neplatná akce: $action"
		return 1
	fi

}

buy_drugs() {
	local drug_choice drug_amount

	clear_screen
	echo "Dealer drog - Vyberte drogu k nákupu:"
	echo "1. Tráva (10$/jednotka)"
	echo "2. Kokain (50$/jednotka)"
	echo "3. Heroin (100$/jednotka)"
	echo "4. Metamfetamin (75$/jednotka)"
	echo "5. Zpět do hlavního menu"
	read -r -p "Zadejte svou volbu (číslo): " drug_choice

	[[ ! "$drug_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo z menu."
		read -r -p "Stiskněte Enter pro pokračování..."
		return
	}
	read -r -p "Zadejte množství, které chcete koupit: " drug_amount
	[[ ! "$drug_amount" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo."
		read -r -p "Stiskněte Enter pro pokračování..."
		return
	}
	case "$drug_choice" in
		1) drug_transaction "buy" "Tráva" 10 "$drug_amount";;
		2) drug_transaction "buy" "Kokain" 50 "$drug_amount";;
		3) drug_transaction "buy" "Heroin" 100 "$drug_amount";;
		4) drug_transaction "buy" "Metamfetamin" 75 "$drug_amount";;
		5) clear_screen; return;;
		*) echo "Neplatná volba."; return;;
	esac
	read -r -p "Stiskněte Enter pro pokračování..."
}

sell_drugs() {
	local drug_choice drug_amount
	clear_screen
	echo "Dealer drog - Vyberte drogu k prodeji:"
	echo "1. Tráva"
	echo "2. Kokain"
	echo "3. Heroin"
	echo "4. Metamfetamin"
	echo "5. Zpět do hlavního menu"
	read -r -p "Zadejte svou volbu (číslo): " drug_choice
	[[ ! "$drug_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo z menu."
		read -r -p "Stiskněte Enter pro pokračování..."
		return
	}
	read -r -p "Zadejte množství, které chcete prodat: " drug_amount
	[[ ! "$drug_amount" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo."
		read -r -p "Stiskněte Enter pro pokračování..."
		return
	}
	case "$drug_choice" in
		1) drug_transaction "sell" "Tráva" 15 "$drug_amount";;
		2) drug_transaction "sell" "Kokain" 75 "$drug_amount";;
		3) drug_transaction "sell" "Heroin" 150 "$drug_amount";;
		4) drug_transaction "sell" "Metamfetamin" 100 "$drug_amount";;
		5) clear_screen; return;;
		*) echo "Neplatná volba."; return;;
	esac
	read -r -p "Stiskněte Enter pro pokračování..."
}

# Funkce pro přehrávání hudby
play_music() {
	local music_files=(
		"music/platforma.mp3"
		"music/metropolis.mp3"
		"music/discovery.mp3"
		"music/search_for_joe.mp3"
		"music/the_loading_screen.mp3"
		"music/doom.mp3"
		"music/Jal.mp3"
	)

	while true; do
		clear_screen
		echo "Vyberte skladbu k přehrání:"
		for i in "${!music_files[@]}"; do
			printf "%d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"
		done
		echo "stiskněte q pro Zastavení hudby"
		printf "%d. Zpět do Hlavního menu\n" $(( ${#music_files[@]} + 1 ))
		read -r music_choice
		if ! [[ "$music_choice" =~ ^[0-9]+$ ]]; then
			echo "Neplatný vstup. Zadejte prosím číslo."
			sleep 2
			continue # Zpět do menu přehrávače hudby
		fi
		if (( music_choice <= ${#music_files[@]} )); then
			local selected_track="${music_files[$((music_choice - 1))]}"
			if [[ -f "$selected_track" ]]; then
				echo "Přehrává se: $(basename "$selected_track")"
				mpg123 -q "$selected_track"
			else
				echo "Chyba: Hudební soubor '$selected_track' nebyl nalezen."
				sleep 2
			fi
		elif (( music_choice == ${#music_files[@]} + 1 )); then
			pkill mpg123
			clear_screen
			break  # Ukončení menu přehrávače hudby
		else
			echo "Neplatná volba."
			sleep 2
		fi
	done
}

# Uložení stavu hry do souboru
save_game() {
	echo "$player_name" > "$SAVE_DIR/player_name.sav"
	echo "$location" > "$SAVE_DIR/location.sav"
	echo "$cash" > "$SAVE_DIR/cash.sav"
	echo "$health" > "$SAVE_DIR/health.sav"
	printf '%s\n' "${guns[@]}" > "$SAVE_DIR/guns.sav"
	printf '%s\n' "${items[@]}" > "$SAVE_DIR/items.sav"
	> "$SAVE_DIR/drugs.sav"
	for key in "${!drugs[@]}"; do
		printf "%s %s\n" "$key" "${drugs[$key]}" >> "$SAVE_DIR/drugs.sav"
	done
	echo "$body_armor_equipped" > "$SAVE_DIR/body_armor_equipped.sav"

	# Uložení dovedností
	> "$SAVE_DIR/skills.sav" # Nejprve vymazat soubor
	for key in "${!skills[@]}"; do
		printf "%s %s\n" "$key" "${skills[$key]}" >> "$SAVE_DIR/skills.sav"
	done

	echo "Hra úspěšně uložena."
	read -r -p "Stiskněte Enter pro pokračování..."
}

# Načtení stavu hry ze souboru
load_game() {
	local IFS=$'\n'
	if [[ -f "$SAVE_DIR/player_name.sav" && -f "$SAVE_DIR/location.sav" && -f "$SAVE_DIR/cash.sav" && -f "$SAVE_DIR/health.sav" && -f "$SAVE_DIR/guns.sav" && -f "$SAVE_DIR/items.sav" && -f "$SAVE_DIR/body_armor_equipped.sav" && -f "$SAVE_DIR/skills.sav" ]]; then
		read -r player_name < "$SAVE_DIR/player_name.sav"
		read -r location < "$SAVE_DIR/location.sav"
		read -r cash < "$SAVE_DIR/cash.sav"
		read -r health < "$SAVE_DIR/health.sav"
		read -r -a guns < "$SAVE_DIR/guns.sav"
		read -r -a items < "$SAVE_DIR/items.sav"
		read -r body_armor_equipped < "$SAVE_DIR/body_armor_equipped.sav"
		declare -A drugs
		while IFS=$'\n' read -r line; do
			if [[ -n "$line" ]]; then
				IFS=$' ' read -r key value <<< "$line"
				drugs["$key"]="$value"
			fi
		done < "$SAVE_DIR/drugs.sav"

		# Načtení dovedností
		declare -A skills
		while IFS=$'\n' read -r line; do
			if [[ -n "$line" ]]; then
				IFS=$' ' read -r key value <<< "$line"
				skills["$key"]="$value"
			fi
		done < "$SAVE_DIR/skills.sav"

		echo "Hra úspěšně načtena."
		read -r -p "Stiskněte Enter pro pokračování..."
		IFS=$' \t\n' # Obnovení IFS
		return 0 # Indikuje úspěšné načtení
	else
		echo "Žádná uložená hra nebyla nalezena."
		read -r -p "Stiskněte Enter pro pokračování..."
		IFS=$' \t\n' # Obnovení IFS
		return 1 # Indikuje neúspěšné načtení
	fi
}

# --- 4. Inicializace hry a smyčka ---

# Funkce pro inicializaci herních proměnných
Game_variables() {
	clear_screen
	read -r -p "Zadejte jméno hráče: " player_name
	play_sfx_mpg "new_game" # Přehrání zvuku Nová hra
	location="Los Santos"
	cash=500
	health=100
	guns=()
	items=()
	declare -A drugs
	drugs=( ["Tráva"]=0 ["Kokain"]=0 ["Heroin"]=0 ["Metamfetamin"]=0 )
	# Inicializace dovedností
	declare -A skills
	skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
	clear_screen
}

# Funkce pro odstranění souborů s uloženou hrou
remove_save_files() {
	rm -f "$SAVE_DIR/player_name.sav"
	rm -f "$SAVE_DIR/location.sav"
	rm -f "$SAVE_DIR/cash.sav"
	rm -f "$SAVE_DIR/health.sav"
	rm -f "$SAVE_DIR/guns.sav"
	rm -f "$SAVE_DIR/items.sav"
	rm -f "$SAVE_DIR/drugs.sav"
	rm -f "$SAVE_DIR/body_armor_equipped.sav"
	rm -f "$SAVE_DIR/skills.sav" # Odstranění souboru s uloženými dovednostmi

	if [[ ! -d "$SAVE_DIR" ]]; then
		echo "Žádná uložená hra nebyla nalezena."
	else
		echo "Staré uložení smazáno!"
	fi
}

# Úvodní herní menu
while true; do
	clear_screen
	echo "Vítejte v Bash Theft Auto"
	echo "Vyberte možnost:"
	echo "1. Nová hra"
	echo "2. Načíst hru"
	echo "3. Ukončit hru"
	read -r -p "Zadejte svou volbu: " initial_choice
	[[ ! "$initial_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo."
		sleep 2
		continue
	}
	case "$initial_choice" in
		1) remove_save_files; Game_variables; break;;
		2) if [[ -d "$SAVE_DIR" ]] && load_game; then break; else continue; fi;;
		3) exit;;
		*) echo "Neplatná volba.";;
	esac
done

while true; do
clear_screen
echo "Vyberte akci:"
echo "1. Cestovat do jiného státu"
echo "2. Koupit zbraně"
echo "3. Zobrazit inventář"
echo "4. Práce (vydělat peníze)"
echo "5. Práce (trestná činnost)"
echo "6. Koupit drogy"
echo "7. Prodat drogy"
echo "8. Najmout prostitutku"
echo "9. Navštívit nemocnici"
echo "10. Ukončit hru"
echo "11. Uložit hru"
echo "12. Načíst hru"
echo "13. Přehrát hudbu"
echo "14. O hře"
read -r -p "Zadejte svou volbu: " choice
[[ ! "$choice" =~ ^[0-9]+$ ]] && {
	echo "Neplatný vstup. Zadejte prosím číslo."
	sleep 2
	continue
}
case "$choice" in
	1) clear
	echo "Vyberte stát, do kterého chcete cestovat:"
	echo "1. Los Santos (50$)"
	echo "2. San Fierro (75$)"
	echo "3. Las Venturas (100$)"
	echo "4. Vice City (150$)"
	echo "5. Liberty City (200$)"
	echo "6. Zpět do hlavního menu"
	read -r -p "Zadejte svou volbu: " city_choice
	[[ ! "$city_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo."
		sleep 2
		continue
	}
	case "$city_choice" in
		1) travel_to 50 "Los Santos";;
		2) travel_to 75 "San Fierro";;
		3) travel_to 100 "Las Venturas";;
		4) travel_to 150 "Vice City";;
		5) travel_to 200 "Liberty City";;
		6) clear_screen;;
		*) echo "Neplatná volba.";;
	esac;;
	2) buy_guns;;
	3) show_inventory;;
	4) clear
	echo "Vyberte práci:"
	echo "1. Taxikář"
	echo "2. Kurýr"
	echo "3. Mechanik"
	echo "4. Hlídač"
	echo "5. Pouliční umělec"
	echo "6. Zpět do hlavního menu"
	read -r -p "Zadejte svou volbu: " job_choice
	[[ ! "$job_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo."
		sleep 2
		continue
	}
	case "$job_choice" in
		1) work_job "taxi";;
		2) work_job "delivery";;
		3) work_job "mechanic";;
		4) work_job "security";;
		5) work_job "performer";;
		6) clear_screen;;
		*) echo "Neplatná volba.";;
	esac;;
	5) clear
	echo "Vyberte trestnou činnost:"
	echo "1. Přepadení"
	echo "2. Gangová válka"
	echo "3. Krádež auta"
	echo "4. Vykrást obchod"
    echo "5. Pouliční závody"
	echo "6. Zpět do hlavního menu"
	read -r -p "Zadejte svou volbu: " criminal_choice
	[[ ! "$criminal_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadejte prosím číslo."
		sleep 2
		continue
	}
	case "$criminal_choice" in
		1) heist;;
		2) gang_war;;
		3) carjack;;
		4) rob_store;;
		5) street_race;;
		6) clear_screen;;
		*) echo "Neplatná volba.";;
	esac;;
	6) buy_drugs;;
	7) sell_drugs;;
	8) hire_hooker;;
	9) visit_hospital;;
	10) exit;;
	11) save_game;;
	12) load_game;;
	13) play_music;;
	14) about_music_sfx;;
	*) echo "Neplatná volba.";;
	esac
done

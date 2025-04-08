#!/bin/bash
#Preklad bol vytvorený umelou inteligenciou
#Bash-Theft-Auto hudba a zvukové efekty © 2024 od stuffbymax - Martin Petik je licencovaný pod CC BY 4.0
#https://creativecommons.org/licenses/by/4.0/
#!/bin/bash
#ver 2.0.2

# --- 0. Globálne premenné ---
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

# --- Nastavenie zvukových efektov ---
sfx_dir="sfx"  # Adresár pre zvukové efekty

#mpg123
# Funkcia pre prehrávanie zvukových efektov (pomocou mpg123)
play_sfx_mpg() {
	local sound_file="$sfx_dir/$1.mp3"
	if [[ -f "$sound_file" ]]; then
		mpg123 -q "$sound_file" &
		return 0  # Indikuje úspech
	else
		echo "Zvukový súbor '$sound_file' nebol nájdený!"
		return 1  # Indikuje neúspech
	fi
}

# --- 1. Načítavanie pluginov ---
plugin_dir="plugins"

if [[ -d "$plugin_dir" ]]; then
	while IFS= read -r -d $'\0' plugin; do
		[[ -f "$plugin" ]] && source "$plugin"
	done < <(find "$plugin_dir" -maxdepth 1 -name "*.sh" -print0)
else
	echo "Varovanie: Adresár pluginov '$plugin_dir' nebol nájdený."
fi

# --- 3. Funkcie ---

# Vyčistí obrazovku a zobrazí informácie o hre
clear_screen() {
clear
printf "\e[93m=========================================\e[0m\n"
printf "\e[1;43m|        Bash theaft auto               |\e[0m\n"
printf "\e[93m=========================================\e[0m\n"
printf "Hráč: %s   Lokácia: %s\n" "$player_name" "$location"
printf "Peniaze: %d dolárov      Zdravie: %d%%\n" "$cash" "$health"
printf "\e[1;34m=========================================\e[0m\n"
printf "\e[1;44m|        vytvorené stuffbymax             |\e[0m\n"
printf "\e[1;34m=========================================\e[0m\n"
}

# --- O hre ---
about_music_sfx() {
	clear_screen
	echo -e "-----------------------------------------"
	echo "|  O hudbe a zvukových efektoch         |"
	echo "-----------------------------------------"
	echo ""
	echo "Hudba a niektoré zvukové efekty v tejto hre"
	echo "boli vytvorené stuffbymax - Martin Petik."
	echo ""
	echo "Sú licencované pod Creative"
	echo "Commons Attribution 4.0 International"
	echo "(CC BY 4.0) licenciou:"
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "To znamená, že ich môžete voľne používať vo"
	echo "svojich vlastných projektoch, aj komerčne,"
	echo "ak uvediete zodpovedajúci kredit."
	echo ""
	echo "Prosím, uveďte hudbu a zvukové"
	echo "efekty s nasledujúcim prehlásením:"
	echo ""
	echo "'Hudba a zvukové efekty © 2024 od"
	echo "stuffbymax - Martin Petik, licencované pod"
	echo "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)'"
	echo ""
	echo "Pre viac informácií o stuffbymax -"
	echo "Martin Petik a mojej práci, navštívte:"
	echo "https://stuffbymax.me/ alebo https://stuffbymax.me/wiki-blogs"
	echo ""
	echo "-----------------------------------------"
	echo "|  Licencia kódu                          |"
	echo "-----------------------------------------"
	echo ""
	echo "Kód pre túto hru je licencovaný pod licenciou MIT."
	echo "Copyright (c) 2024 stuffbymax"
	echo "Môžete ho voľne používať, upravovať a distribuovať"
	echo "s riadnym uvedením autora."
	echo ""
	echo "Pre plné znenie licencie navštívte:"
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE"
	echo ""
	echo "Ďakujeme za hranie!"
	read -r -p "Stlačte Enter pre návrat do hlavného menu..."
}

# Funkcia pre kontrolu, či je hráč nažive
check_health() {
	if (( health <= 0 )); then
		echo "Nemáte žiadne zdravie! Preprava do nemocnice..."
		read -r -p "Stlačte Enter pre pokračovanie..."
		hospitalize_player
	fi
}

# Funkcia pre cestovanie na nové miesto
travel_to() {
	local travel_cost="$1"
	local new_location="$2"

	if (( cash >= travel_cost )); then
		echo "Cestovanie do $new_location..."
		play_sfx_mpg "air"

		# --- Animácia leteckej dopravy (Volanie pluginu) ---
		air_travel_animation # Volanie funkcie v animation.sh
		# --- Koniec animácie leteckej dopravy ---

		cash=$((cash - travel_cost))
		# Odstráňte výzvu stlačenia Enter tu, je zbytočná s animáciou

		location="$new_location"
		clear_screen
		echo "Dorazili ste do $new_location."
	else
		echo "Nedostatok peňazí na cestu do $new_location."
		read -r -p "Stlačte Enter pre pokračovanie..."
		clear_screen
	fi
}

# Funkcia pre nákup zbraní
buy_guns() {
	local gun_choice
	clear_screen
	echo "Obchod so zbraňami - Vyberte zbraň na nákup:"
	echo "1. Pištoľ (100$)"
	echo "2. Brokovnica (250$)"
	echo "3. SMG (500$)"
	echo "4. Puška (750$)"
	echo "5. Sniper (1000$)"
	echo "6. Späť do hlavného menu"
	read -r -p "Zadajte svoju voľbu (číslo): " gun_choice

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo z menu."
		read -r -p "Stlačte Enter pre pokračovanie..."
		return
	}

	case "$gun_choice" in
		1) buy_item "Pištoľ" 100;;
		2) buy_item "Brokovnica" 250;;
		3) buy_item "SMG" 500;;
		4) buy_item "Puška" 750;;
		5) buy_item "Sniper" 1000;;
		6) clear_screen;;
		*) echo "Neplatná voľba.";;
	esac
}

# Pomocná funkcia pre nákup položiek
buy_item() {
	local item_name="$1"
	local item_cost="$2"
	play_sfx_mpg "cash_register"
	buy_animation

	if (( cash >= item_cost )); then
		cash=$((cash - item_cost))
		guns+=("$item_name")
		echo "Kúpili ste si $item_name."
		read -r -p "Stlačte Enter pre pokračovanie..."
	else
		echo "Nedostatok peňazí na kúpu $item_name."
		read -r -p "Stlačte Enter pre pokračovanie..."
	fi
}

# Funkcia pre zobrazenie inventára
show_inventory() {
	clear_screen
	echo "Váš inventár:"
	printf "Peniaze: %d dolárov\n" "$cash"
	printf "Zdravie: %d%%\n" "$health"
	printf "Zbrane: %s\n" "${guns[*]}"
	printf "Predmety: %s\n" "${items[*]}"
	echo "Drogy: "
	local IFS=$'\n'
	for drug in "${!drugs[@]}"; do
		printf "  - %s: %s\n" "$drug" "${drugs[$drug]}"
	done
	IFS=$' \t\n' # Obnovenie IFS

	echo "Dovednosti:"
	local IFS=$'\n'
	for skill in "${!skills[@]}"; do
		printf "  - %s: %s\n" "$skill" "${skills[$skill]}"
	done
	IFS=$' \t\n' # Obnovenie IFS
	read -r -p "Stlačte Enter pre návrat do hlavného menu."
}

# Funkcia pre prácu (zjednodušená logika)
work_job() {
	local job_type="$1"
	local earnings
	local min_earnings max_earnings
	local driving_skill=$((skills["driving"] * 5)) #Príklad použitia dovedností

	case "$location" in
		"Los Santos") min_earnings=20; max_earnings=$((60 + driving_skill));;
		"San Fierro") min_earnings=25; max_earnings=$((70 + driving_skill));;
		"Las Venturas") min_earnings=30; max_earnings=$((90 + driving_skill));;
		"Vice City") min_earnings=15; max_earnings=$((50 + driving_skill));;
		"Liberty City") min_earnings=35; max_earnings=$((100 + driving_skill));;
		*) min_earnings=10; max_earnings=$((40 + driving_skill));; # Výchozie hodnoty
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
		*) echo "Neplatná práca"; return;;
	esac

	echo "Pracujete ako $job_type vodič v $location..."
	read -r -p "Stlačte Enter pre pokračovanie..."

	cash=$((cash + earnings))
	clear_screen
	printf "Zarobili ste %d dolárov. Teraz máte %d dolárov.\n" "$earnings" "$cash"
	read -r -p "Stlačte Enter pre pokračovanie..."
}

# Funkcia pre pouličné preteky (samostatná funkcia)
street_race() {
	working_animation
	echo "Zúčastňujete sa pouličných pretekov v $location..."
	read -r -p "Stlačte Enter pre pokračovanie..."
	local winnings
	local damage
	local driving_skill=$((skills["driving"] * 5))
	local win_chance=$((50 + driving_skill)) # Ovplyvňuje šancu na výhru

	if (( RANDOM % 100 < win_chance )); then
		winnings=$((RANDOM % 201 + 100))
		cash=$((cash + winnings))
		damage=$((RANDOM % 21 + 10))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaša nepriestrelná vesta znížila poškodenie!"
			body_armor_equipped=false
		fi
		health=$((health - damage))
		check_health
		clear_screen
		printf "Vyhrali ste pouličné preteky a získali %d dolárov, ale stratili %d%% zdravia. Teraz máte %d dolárov a %d%% zdravia.\n" "$winnings" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Prehranie zvuku výhry
		read -r -p "Stlačte Enter pre pokračovanie..."
	else
		damage=$((RANDOM % 41 + 20))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaša nepriestrelná vesta znížila poškodenie!"
			body_armor_equipped=false
		fi
		health=$((health - damage))
		check_health
		clear_screen
		printf "Prehrali ste pouličné preteky a utrpeli %d%% poškodenie. Teraz máte %d%% zdravia.\n" "$damage" "$health"
		play_sfx_mpg "lose" # Prehranie zvuku prehry
		read -r -p "Stlačte Enter pre pokračovanie..."
	fi
}

# Funkcia pre použitie zbraní pre prácu - aktuálne sa nepoužíva v prácach, ale ponechaná pre potenciálne budúce použitie.
use_guns() {
	if [[ " ${guns[*]} " == *" $1 "* ]]; then
		echo "Použili ste svoj $1 pre túto prácu."
		play_sfx_mpg "gun_shot"
		read -r -p "Stlačte Enter pre pokračovanie..."
	else
		echo "Nemáte $1. Práca zlyhala."
		read -r -p "Stlačte Enter pre pokračovanie..."
	fi
}

# Funkcia pre návštevu nemocnice
visit_hospital() {
	local hospital_choice
	clear_screen
	echo "Nemocničné služby:"
	echo "1. Základné ošetrenie (50$) - Plné uzdravenie"
	echo "2. Pokročilé ošetrenie (100$) - Plné uzdravenie + 10% bonus zdravia"
	echo "3. Kúpiť lekárničku (30$) - Uzdravenie 25% zdravia"
	echo "4. Kúpiť nepriestrelnú vestu (75$) - Zníženie poškodenia o 50% v budúcom strete"
	echo "5. Späť do hlavného menu"
	read -r -p "Zadajte svoju voľbu (číslo): " hospital_choice

	[[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo z menu."
		read -r -p "Stlačte Enter pre pokračovanie..."
		return
	}

	case "$hospital_choice" in
		1) buy_hospital_item 50 "basic_treatment";;
		2) buy_hospital_item 100 "advanced_treatment";;
		3) buy_hospital_item 30 "health_pack";;
		4) buy_hospital_item 75 "body_armor";;
		5) clear_screen;;
		*) echo "Neplatná voľba.";;
	esac
}

# Pomocná funkcia pre nákup nemocničných položiek
buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2"

	if (( cash >= item_cost )); then
		cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment")
				health=100
				echo "Obdržali ste základné ošetrenie a ste plne uzdravení."
				play_sfx_mpg "heal" # Prehranie zvuku uzdravenia
				read -r -p "Stlačte Enter pre pokračovanie..."
				;;
			"advanced_treatment")
				health=$((health + 10))
				(( health > 100 )) && health=100
				echo "Obdržali ste pokročilé ošetrenie a ste plne uzdravení s bonusom zdravia."
				play_sfx_mpg "heal" # Prehranie zvuku uzdravenia
				read -r -p "Stlačte Enter pre pokračovanie..."
				;;
			"health_pack")
				items+=("Lekárnička")
				echo "Kúpili ste si lekárničku."
				play_sfx_mpg "item_buy" # Prehranie zvuku nákupu položky
				read -r -p "Stlačte Enter pre pokračovanie..."
				;;
			"body_armor")
				body_armor_equipped=true
				echo "Kúpili ste si nepriestrelnú vestu."
				play_sfx_mpg "item_buy" # Prehranie zvuku nákupu položky
				read -r -p "Stlačte Enter pre pokračovanie..."
				;;
		esac
	else
		echo "Nedostatok peňazí na $item_type."
		read -r -p "Stlačte Enter pre pokračovanie..."
	fi
}

# Funkcia pre vykradnutie obchodu
rob_store() {
	robbing_animation
	echo "Pokúša sa vykradnúť obchod v $location..."

	local stealth_skill=$((skills["stealth"] * 5)) # Základná dovednosť plíženia
	local gun_bonus=0 # Inicializácia bonusu zbrane

	if (( ${#guns[@]} > 0 )); then
		echo "Chcete použiť zbraň? (a/n)"
		read -r use_gun

	if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then
			echo "Ktorú zbraň chcete použiť? (Zadajte názov zbrane)"
			echo "Dostupné zbrane: ${guns[*]}"
			read -r chosen_gun

			# Kontrola, či hráč má danú zbraň
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "Použili ste $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Prehranie zvuku výstrelu

				# --- Aplikácia bonusu zbrane ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}" # Extrahovanie reťazca atribútov
					gun_bonus=$success_bonus # Získanie bonusu za úspech
					stealth_skill=$((stealth_skill + gun_bonus)) # Aplikácia bonusu
					echo "$chosen_gun vám dáva +${gun_bonus}% šancu na úspech."
				else
					echo "Pre $chosen_gun nie sú definované žiadne atribúty (Toto je chyba skriptu)."
				fi
				# --- Koniec bonusu zbrane ---
			else
				echo "Nemáte túto zbraň!"
			fi
		else
			echo "Pokračovanie bez zbrane."
		fi
	else
		echo "Nemáte žiadne zbrane!"
	fi

	read -r -p "Stlačte Enter pre pokračovanie..."

	local loot
	local damage
	local fine
	if (( RANDOM % 100 < stealth_skill )); then
		loot=$((RANDOM % 201 + 100))
		cash=$((cash + loot))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaša nepriestrelná vesta znížila poškodenie!"
			body_armor_equipped=false
		fi

		damage=$((RANDOM % 31 + 10))
		health=$((health - damage))
		check_health
		clear_screen
		printf "Úspešne ste vykradli obchod a získali %d dolárov, ale stratili %d%% zdravia. Teraz máte %d dolárov a %d%% zdravia.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "cash_register"
		read -r -p "Stlačte Enter pre pokračovanie..."
	else
		fine=$((RANDOM % 51 + 25))
		cash=$((cash - fine))
		clear_screen
		printf "Boli ste chytení a pokutovaní %d dolármi. Teraz máte %d dolárov.\n" "$fine" "$cash"
		play_sfx_mpg "lose"   # Prehranie zvuku prehry
		read -r -p "Stlačte Enter pre pokračovanie..."
	fi
}

# Funkcia pre účasť na prepadnutí
heist() {
	heist_animation
	echo "Plánovanie prepadnutia v $location..."

	local stealth_skill=$((skills["stealth"] * 5)) # Základná dovednosť plíženia
	local gun_bonus=0 # Inicializácia bonusu zbrane

	if (( ${#guns[@]} > 0 )); then
		echo "Chcete použiť zbraň? (a/n)"
		read -r use_gun

		if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then
			echo "Ktorú zbraň chcete použiť? (Zadajte názov zbrane)"
			echo "Dostupné zbrane: ${guns[*]}"
			read -r chosen_gun
			# Kontrola, či hráč má danú zbraň
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "Použili ste $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Prehranie zvuku výstrelu

				# --- Logika bonusu zbrane ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
					gun_bonus=$success_bonus
					stealth_skill=$((stealth_skill + gun_bonus))
					echo "$chosen_gun vám dáva +${gun_bonus}% šancu na úspech."
				else
					echo "Pre $chosen_gun nie sú definované žiadne atribúty (Toto je chyba skriptu)."
				fi
				# --- Koniec logiky bonusu zbrane ---

			else
				echo "Nemáte túto zbraň!"
			fi
		else
			echo "Pokračovanie bez zbrane."
		fi
	else
		echo "Nemáte žiadne zbrane!"
	fi

	read -r -p "Stlačte Enter pre pokračovanie..."

	local loot
	local damage
	local fine
	if (( RANDOM % 100 < stealth_skill )); then
		loot=$((RANDOM % 501 + 200))
		cash=$((cash + loot))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaša nepriestrelná vesta znížila poškodenie!"
			body_armor_equipped=false
		fi

		damage=$((RANDOM % 51 + 20))
		health=$((health - damage))
		check_health
		clear_screen
		printf "Prepadnutie bolo úspešné! Získali ste %d dolárov, ale stratili %d%% zdravia. Teraz máte %d dolárov a %d%% zdravia.\n" "$loot" "$damage" "$cash" "$health"
		read -r -p "Stlačte Enter pre pokračovanie..."
	else
		fine=$((RANDOM % 101 + 50))
		cash=$((cash - fine))

		clear_screen
		printf "Prepadnutie zlyhalo a boli ste chytení, stratili ste %d dolárov. Teraz máte %d dolárov.\n" "$fine" "$cash"
		play_sfx_mpg "lose"  # Prehranie zvuku prehry
		read -r -p "Stlačte Enter pre pokračovanie..."
	fi
}

# Funkcia pre gangové vojny
gang_war() {
	# Kontrola, či hráč má nejaké zbrane
	if (( ${#guns[@]} == 0 )); then
		echo "Nemôžete začať gangovú vojnu bez zbrane!"
		read -r -p "Stlačte Enter pre pokračovanie..."
		return
	fi

	gang_war_animation
	echo "Začína gangová vojna v $location..."

	local strength_skill=$((skills["strength"] * 5)) # Základná dovednosť sily
	local gun_bonus=0 # Inicializácia bonusu zbrane

	if (( ${#guns[@]} > 0 )); then
		echo "Chcete použiť zbraň? (a/n)"
		read -r use_gun

		if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then
			echo "Ktorú zbraň chcete použiť? (Zadajte názov zbrane)"
			echo "Dostupné zbrane: ${guns[*]}"
			read -r chosen_gun

			# Kontrola, či hráč má danú zbraň
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "Použili ste $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Prehranie zvuku výstrelu

				# --- Logika bonusu zbrane ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
					gun_bonus=$success_bonus
					strength_skill=$((strength_skill + gun_bonus)) # Použitie strength_skill tu
					echo "$chosen_gun vám dáva +${gun_bonus}% šancu na úspech."
				else
					echo "Pre $chosen_gun nie sú definované žiadne atribúty (Toto je chyba skriptu)."
				fi
				# --- Koniec logiky bonusu zbrane ---

			else
				echo "Nemáte túto zbraň!"
			fi
		else
			echo "Pokračovanie bez zbrane."
		fi
	else
		echo "Nemáte žiadne zbrane!"
	fi

	read -r -p "Stlačte Enter pre pokračovanie..."

	local loot
	local damage
	local fine

	if (( RANDOM % 100 < strength_skill )); then
		loot=$((RANDOM % 301 + 100))
		cash=$((cash + loot))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaša nepriestrelná vesta znížila poškodenie!"
			body_armor_equipped=false
		fi

		damage=$((RANDOM % 51 + 30))
		health=$((health - damage))
		check_health
		clear_screen
		printf "Vyhrali ste gangovú vojnu a získali %d dolárov, ale stratili %d%% zdravia. Teraz máte %d dolárov a %d%% zdravia.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Prehranie zvuku gangovej vojny
		read -r -p "Stlačte Enter pre pokračovanie..."
	else
		fine=$((RANDOM % 151 + 50))
		cash=$((cash - fine))
		damage=$((RANDOM % 41 + 20))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Vaša nepriestrelná vesta znížila poškodenie!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Prehrali ste gangovú vojnu, boli ste pokutovaní %d dolármi a stratili %d%% zdravia. Teraz máte %d dolárov a %d%% zdravia.\n" "$fine" "$damage" "$cash" "$health"
		play_sfx_mpg "lose"  # Prehranie zvuku prehry
		read -r -p "Stlačte Enter pre pokračovanie..."
	fi
}

# Funkcia pre krádež auta
carjack() {
	# Kontrola, či hráč má nejaké zbrane
	if (( ${#guns[@]} == 0 )); then
		# Upozornenie hráča, že nemá zbraň
		echo "Nemáte zbraň, takže sa budete musieť spoľahnúť na svoje dovednosti. To sťaží krádež auta."
		read -r -p "Stlačte Enter pre pokračovanie..."
		success_chance=$((success_chance - 20))  # Zníženie šance na úspech, keď nie je k dispozícii zbraň
	fi

	# Kontrola, či sa hráč rozhodol použiť zbraň
	if (( ${#guns[@]} > 0 )); then
		# Dotaz na hráča, či chce použiť zbraň
		echo "Chcete použiť zbraň? (a/n)"
		read -r use_gun

		if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then
			# Výpis dostupných zbraní
			echo "Ktorú zbraň chcete použiť? (Zadajte názov zbrane)"
			echo "Dostupné zbrane: ${guns[*]}"
			read -r chosen_gun

			# Kontrola, či hráč má vybranú zbraň
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "Použili ste $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Prehranie zvuku výstrelu
				local gun_bonus=0 # Inicializácia bonusu zbrane tu vnútri bloku if $gun_found

				# --- Logika bonusu zbrane ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
					gun_bonus=$success_bonus
					success_chance=$((success_chance + gun_bonus)) # Aplikácia na success_chance
					echo "$chosen_gun vám dáva +${gun_bonus}% šancu na úspech."
				else
					echo "Pre $chosen_gun nie sú definované žiadne atribúty (Toto je chyba skriptu)."
				fi
				# --- Koniec logiky bonusu zbrane ---

			else
				echo "Nemáte túto zbraň!"
				# Pokračovanie bez zbrane, ak vybraná zbraň neexistuje
				echo "Pokračovanie bez zbrane."
				success_chance=$((success_chance - 20))  # Zníženie šance na úspech bez zbrane (-20)
			fi
		else
			# Ak sa hráč rozhodne nepoužiť zbraň, pokračovanie bez nej
			echo "Pokračovanie bez zbrane."
			success_chance=$((success_chance - 20))  # Zníženie šance na úspech bez zbrane (-20)
		fi
	fi

	# Spustenie animácie krádeže auta po rozhodnutí
	carjacking_animation
	echo "Pokúša sa ukradnúť vozidlo v $location..."
	read -r -p "Stlačte Enter pre pokračovanie..."

	local loot
	local damage
	local fine
	local driving_skill=$((skills["driving"] * 5))
	local stealth_skill=$((skills["stealth"] * 5))
	success_chance=$((driving_skill + stealth_skill + success_chance))

	# Teraz vypočítať šancu na úspech po zvážení zbrane
	if (( RANDOM % 100 < success_chance )); then
		loot=$((RANDOM % 201 + 50))
		cash=$((cash + loot))

		damage=$((RANDOM % 21 + 10))

		if [[ "$body_armor_equipped" == true ]]; then
			damage=$((damage / 2))
			echo "Vaša nepriestrelná vesta znížila poškodenie!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Úspešne ste ukradli vozidlo a získali %d dolárov, ale stratili %d%% zdravia.\nTeraz máte %d dolárov a %d%% zdravia.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "car_start"  # Prehranie zvuku krádeže auta
		read -r -p "Stlačte Enter pre pokračovanie..."
	else
		fine=$((RANDOM % 76 + 25))
		cash=$((cash - fine))
		clear_screen
		printf "Boli ste chytení a pokutovaní %d dolármi. Teraz máte %d dolárov.\n" "$fine" "$cash"
		play_sfx_mpg "lose"  # Prehranie zvuku prehry
		read -r -p "Stlačte Enter pre pokračovanie..."
	fi
}

# Funkcia pre ošetrenie v nemocnici po smrti
hospitalize_player() {
	clear_screen
	echo "Boli ste hospitalizovaní a ste liečení..."
	read -r -p "Stlačte Enter pre pokračovanie..."
	health=100
	clear_screen
	echo "Ste plne uzdravení, ale stratili ste 200 dolárov za liečbu."
	cash=$((cash - 200))
	(( cash < 0 )) && cash=0
	read -r -p "Stlačte Enter pre pokračovanie..."
	clear_screen
}

# Funkcia pre najmutie prostitútky
hire_hooker() {
	echo "Hľadáte prostitútku v $location..."
	read -r -p "Stlačte Enter pre pokračovanie..."
	local hooker_cost
	local health_gain
	local charisma_skill=$(( skills["charisma"] * 2 ))  # Ovplyvňuje cenu
	# Zabezpečenie, že charisma_skill je v rozumnom rozsahu
	(( charisma_skill > 99 )) && charisma_skill=99
	# Zabezpečenie, že rozsah RANDOM je pozitívny
	local min_cost=$(( 50 - charisma_skill ))
	local max_cost=$(( 101 - charisma_skill ))
	(( min_cost < 1 )) && min_cost=1
	(( max_cost <= min_cost )) && max_cost=$(( min_cost + 10 ))  # Zabezpečenie platného rozsahu
	hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	# Zabezpečenie minimálnej ceny
	(( hooker_cost < 10 )) && hooker_cost=10
	health_gain=$(( RANDOM % 21 + 10 ))
	if (( cash >= hooker_cost )); then
	cash=$(( cash - hooker_cost ))
	health=$(( health + health_gain ))
	(( health > 100 )) && health=100
	clear_screen
	printf "Najali ste si prostitútku za %d dolárov a získali %d%% zdravia.\nTeraz máte %d dolárov a %d%% zdravia.\n" \
	"$hooker_cost" "$health_gain" "$cash" "$health"
	play_sfx_mpg "hooker"  # Prehranie zvuku prostitútky
	read -r -p "Stlačte Enter pre pokračovanie..."
else
	clear_screen
	echo "Nedostatok peňazí na najmutie prostitútky."
	read -r -p "Stlačte Enter pre pokračovanie..."
	fi

clear_screen
}


# Centralizovaná funkcia transakcie drog
drug_transaction() {
	local action="$1" # "buy" alebo "sell"
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
			printf "Kúpili ste %s jednotiek %s.\n" "$drug_amount" "$drug_name"
			play_sfx_mpg "cash_register"
			return 0
		else
			echo "Nedostatok peňazí na kúpu $drug_name."
			return 1
		fi
	elif [[ "$action" == "sell" ]]; then
		if [[ -v "drugs[$drug_name]" ]] && (( drugs["$drug_name"] >= drug_amount )); then
			drug_transaction_animation

			# Úprava predajnej ceny na základe dovednosti
			local price_modifier=$((drug_dealer_skill * 2)) # Príklad: 2% nárast za bod dovednosti
			local adjusted_price=$((drug_price + (drug_price * price_modifier / 100)))

			income=$((adjusted_price * drug_amount))
			cash=$((cash + income))
			drugs["$drug_name"]=$((drugs["$drug_name"] - drug_amount))

			printf "Predali ste %s jednotiek %s za %d dolárov (upravené podľa vašich dovedností predaja drog).\n" "$drug_amount" "$drug_name" "$income"
			play_sfx_mpg "cash_register"
			# Zvýšenie dovednosti predaja drog
			skills["drug_dealer"]=$((drug_dealer_skill + 1)) # Jednoduché zvýšenie
			echo "Vaša dovednosť predaja drog sa zvýšila!"
			return 0
		else
			echo "Nedostatok $drug_name na predaj."
			return 1
		fi
	else
		echo "Neplatná akcia: $action"
		return 1
	fi

}

buy_drugs() {
	local drug_choice drug_amount

	clear_screen
	echo "Drogový díler - Vyberte drogu na nákup:"
	echo "1. Tráva (10$/jednotka)"
	echo "2. Kokaín (50$/jednotka)"
	echo "3. Heroín (100$/jednotka)"
	echo "4. Metamfetamín (75$/jednotka)"
	echo "5. Späť do hlavného menu"
	read -r -p "Zadajte svoju voľbu (číslo): " drug_choice

	[[ ! "$drug_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo z menu."
		read -r -p "Stlačte Enter pre pokračovanie..."
		return
	}
	read -r -p "Zadajte množstvo, ktoré chcete kúpiť: " drug_amount
	[[ ! "$drug_amount" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo."
		read -r -p "Stlačte Enter pre pokračovanie..."
		return
	}
	case "$drug_choice" in
		1) drug_transaction "buy" "Tráva" 10 "$drug_amount";;
		2) drug_transaction "buy" "Kokaín" 50 "$drug_amount";;
		3) drug_transaction "buy" "Heroín" 100 "$drug_amount";;
		4) drug_transaction "buy" "Metamfetamín" 75 "$drug_amount";;
		5) clear_screen; return;;
		*) echo "Neplatná voľba."; return;;
	esac
	read -r -p "Stlačte Enter pre pokračovanie..."
}

sell_drugs() {
	local drug_choice drug_amount
	clear_screen
	echo "Drogový díler - Vyberte drogu na predaj:"
	echo "1. Tráva"
	echo "2. Kokaín"
	echo "3. Heroín"
	echo "4. Metamfetamín"
	echo "5. Späť do hlavného menu"
	read -r -p "Zadajte svoju voľbu (číslo): " drug_choice
	[[ ! "$drug_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo z menu."
		read -r -p "Stlačte Enter pre pokračovanie..."
		return
	}
	read -r -p "Zadajte množstvo, ktoré chcete predať: " drug_amount
	[[ ! "$drug_amount" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo."
		read -r -p "Stlačte Enter pre pokračovanie..."
		return
	}
	case "$drug_choice" in
		1) drug_transaction "sell" "Tráva" 15 "$drug_amount";;
		2) drug_transaction "sell" "Kokaín" 75 "$drug_amount";;
		3) drug_transaction "sell" "Heroín" 150 "$drug_amount";;
		4) drug_transaction "sell" "Metamfetamín" 100 "$drug_amount";;
		5) clear_screen; return;;
		*) echo "Neplatná voľba."; return;;
	esac
	read -r -p "Stlačte Enter pre pokračovanie..."
}

# Funkcia pre prehrávanie hudby
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
		echo "Vyberte skladbu na prehratie:"
		for i in "${!music_files[@]}"; do
			printf "%d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"
		done
		echo "stlačte q pre Zastavenie hudby"
		printf "%d. Späť do Hlavného menu\n" $(( ${#music_files[@]} + 1 ))
		read -r music_choice
		if ! [[ "$music_choice" =~ ^[0-9]+$ ]]; then
			echo "Neplatný vstup. Zadajte prosím číslo."
			sleep 2
			continue # Späť do menu prehrávača hudby
		fi
		if (( music_choice <= ${#music_files[@]} )); then
			local selected_track="${music_files[$((music_choice - 1))]}"
			if [[ -f "$selected_track" ]]; then
				echo "Prehráva sa: $(basename "$selected_track")"
				mpg123 -q "$selected_track"
			else
				echo "Chyba: Hudobný súbor '$selected_track' nebol nájdený."
				sleep 2
			fi
		elif (( music_choice == ${#music_files[@]} + 1 )); then
			pkill mpg123
			clear_screen
			break  # Ukončenie menu prehrávača hudby
		else
			echo "Neplatná voľba."
			sleep 2
		fi
	done
}

# Uloženie stavu hry do súboru
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

	# Uloženie dovedností
	> "$SAVE_DIR/skills.sav" # Najprv vymazať súbor
	for key in "${!skills[@]}"; do
		printf "%s %s\n" "$key" "${skills[$key]}" >> "$SAVE_DIR/skills.sav"
	done

	echo "Hra úspešne uložená."
	read -r -p "Stlačte Enter pre pokračovanie..."
}

# Načítanie stavu hry zo súboru
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

		# Načítanie dovedností
		declare -A skills
		while IFS=$'\n' read -r line; do
			if [[ -n "$line" ]]; then
				IFS=$' ' read -r key value <<< "$line"
				skills["$key"]="$value"
			fi
		done < "$SAVE_DIR/skills.sav"

		echo "Hra úspešne načítaná."
		read -r -p "Stlačte Enter pre pokračovanie..."
		IFS=$' \t\n' # Obnovenie IFS
		return 0 # Indikuje úspešné načítanie
	else
		echo "Žiadna uložená hra nebola nájdená."
		read -r -p "Stlačte Enter pre pokračovanie..."
		IFS=$' \t\n' # Obnovenie IFS
		return 1 # Indikuje neúspešné načítanie
	fi
}

# --- 4. Inicializácia hry a slučka ---

# Funkcia pre inicializáciu herných premenných
Game_variables() {
	clear_screen
	read -r -p "Zadajte meno hráča: " player_name
	play_sfx_mpg "new_game" # Prehranie zvuku Nová hra
	location="Los Santos"
	cash=500
	health=100
	guns=()
	items=()
	declare -A drugs
	drugs=( ["Tráva"]=0 ["Kokaín"]=0 ["Heroín"]=0 ["Metamfetamín"]=0 )
	# Inicializácia dovedností
	declare -A skills
	skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
	clear_screen
}

# Funkcia pre odstránenie súborov s uloženou hrou
remove_save_files() {
	rm -f "$SAVE_DIR/player_name.sav"
	rm -f "$SAVE_DIR/location.sav"
	rm -f "$SAVE_DIR/cash.sav"
	rm -f "$SAVE_DIR/health.sav"
	rm -f "$SAVE_DIR/guns.sav"
	rm -f "$SAVE_DIR/items.sav"
	rm -f "$SAVE_DIR/drugs.sav"
	rm -f "$SAVE_DIR/body_armor_equipped.sav"
	rm -f "$SAVE_DIR/skills.sav" # Odstránenie súboru s uloženými dovednosťami

	if [[ ! -d "$SAVE_DIR" ]]; then
		echo "Žiadna uložená hra nebola nájdená."
	else
		echo "Staré uloženie zmazané!"
	fi
}

# Úvodné herné menu
while true; do
	clear_screen
	echo "Vitajte v Bash Theft Auto"
	echo "Vyberte možnosť:"
	echo "1. Nová hra"
	echo "2. Načítať hru"
	echo "3. Ukončiť hru"
	read -r -p "Zadajte svoju voľbu: " initial_choice
	[[ ! "$initial_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo."
		sleep 2
		continue
	}
	case "$initial_choice" in
		1) remove_save_files; Game_variables; break;;
		2) if [[ -d "$SAVE_DIR" ]] && load_game; then break; else continue; fi;;
		3) exit;;
		*) echo "Neplatná voľba.";;
	esac
done

while true; do
clear_screen
echo "Vyberte akciu:"
echo "1. Cestovať do iného štátu"
echo "2. Kúpiť zbrane"
echo "3. Zobraziť inventár"
echo "4. Práca (zarobiť peniaze)"
echo "5. Práca (trestná činnosť)"
echo "6. Kúpiť drogy"
echo "7. Predať drogy"
echo "8. Najmúť prostitútku"
echo "9. Navštíviť nemocnicu"
echo "10. Ukončiť hru"
echo "11. Uložiť hru"
echo "12. Načítať hru"
echo "13. Prehrať hudbu"
echo "14. O hre"
read -r -p "Zadajte svoju voľbu: " choice
[[ ! "$choice" =~ ^[0-9]+$ ]] && {
	echo "Neplatný vstup. Zadajte prosím číslo."
	sleep 2
	continue
}
case "$choice" in
	1) clear
	echo "Vyberte štát, do ktorého chcete cestovať:"
	echo "1. Los Santos (50$)"
	echo "2. San Fierro (75$)"
	echo "3. Las Venturas (100$)"
	echo "4. Vice City (150$)"
	echo "5. Liberty City (200$)"
	echo "6. Späť do hlavného menu"
	read -r -p "Zadajte svoju voľbu: " city_choice
	[[ ! "$city_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo."
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
		*) echo "Neplatná voľba.";;
	esac;;
	2) buy_guns;;
	3) show_inventory;;
	4) clear
	echo "Vyberte prácu:"
	echo "1. Taxikár"
	echo "2. Kuriér"
	echo "3. Mechanik"
	echo "4. Strážnik"
	echo "5. Pouličný umelec"
	echo "6. Späť do hlavného menu"
	read -r -p "Zadajte svoju voľbu: " job_choice
	[[ ! "$job_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo."
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
		*) echo "Neplatná voľba.";;
	esac;;
	5) clear
	echo "Vyberte trestnú činnosť:"
	echo "1. Prepadnutie"
	echo "2. Gangová vojna"
	echo "3. Krádež auta"
	echo "4. Vykradnúť obchod"
    echo "5. Pouličné preteky"
	echo "6. Späť do hlavného menu"
	read -r -p "Zadajte svoju voľbu: " criminal_choice
	[[ ! "$criminal_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup. Zadajte prosím číslo."
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
		*) echo "Neplatná voľba.";;
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
	*) echo "Neplatná voľba.";;
	esac
done

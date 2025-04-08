#!/bin/bash
#Bash-Theft-Auto music and sfx © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
#https://creativecommons.org/licenses/by/4.0/
#!/bin/bash
#версия 2.0.2

# --- 0. Глобальные переменные ---
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

# Атрибуты оружия (внутренние ключи остаются английскими)
gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

# --- Настройка звуковых эффектов ---
sfx_dir="sfx"  # Директория для звуковых эффектов

#mpg123
# Функция для воспроизведения звуковых эффектов (используя mpg123)
play_sfx_mpg() {
	local sound_file="$sfx_dir/$1.mp3"
	if [[ -f "$sound_file" ]]; then
		mpg123 -q "$sound_file" &
		return 0  # Успех
	else
		echo "Звуковой файл '$sound_file' не найден!"
		return 1  # Неудача
	fi
}

# --- 1. Загрузка плагинов ---
plugin_dir="plugins"

if [[ -d "$plugin_dir" ]]; then
	while IFS= read -r -d $'\0' plugin; do
		[[ -f "$plugin" ]] && source "$plugin"
	done < <(find "$plugin_dir" -maxdepth 1 -name "*.sh" -print0)
else
	echo "Предупреждение: Директория плагинов '$plugin_dir' не найдена."
fi

# --- 3. Функции ---

# Очистка экрана и отображение информации об игре
clear_screen() {
clear
printf "\e[93m=========================================\e[0m\n"
printf "\e[1;43m|        Bash theaft auto               |\e[0m\n" # Можно перевести название, если нужно
printf "\e[93m=========================================\e[0m\n"
printf "Игрок: %s   Местоположение: %s\n" "$player_name" "$location"
printf "Деньги: %d долларов      Здоровье: %d%%\n" "$cash" "$health"
printf "\e[1;34m=========================================\e[0m\n"
printf "\e[1;44m|        Сделано stuffbymax             |\e[0m\n" # Переведено "made by"
printf "\e[1;34m=========================================\e[0m\n"
}

# --- О программе ---
about_music_sfx() {
	clear_screen
	echo -e "-----------------------------------------"
	echo "|  О Музыке и Звуковых Эффектах         |"
	echo "-----------------------------------------"
	echo ""
	echo "Музыка и некоторые звуковые эффекты в этой игре"
	echo "были созданы stuffbymax - Martin Petik."
	echo ""
	echo "Они лицензированы по лицензии Creative"
	echo "Commons Attribution 4.0 International"
	echo "(CC BY 4.0):"
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "Это означает, что вы можете свободно использовать их в"
	echo "своих собственных проектах, даже в коммерческих целях,"
	echo "при условии указания соответствующего авторства."
	echo ""
	echo "Пожалуйста, указывайте авторство музыки и звуковых"
	echo "эффектов следующим образом:"
	echo ""
	echo "'Музыка и звуковые эффекты © 2024"
	echo "stuffbymax - Martin Petik, лицензировано по"
	echo "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)'"
	echo ""
	echo "Для получения дополнительной информации о stuffbymax -"
	echo "Martin Petik и моей работе, пожалуйста, посетите:"
	echo "https://stuffbymax.me/ или https://stuffbymax.me/wiki-blogs"
	echo ""
	echo "-----------------------------------------"
	echo "|  Лицензия на код                      |"
	echo "-----------------------------------------"
	echo ""
	echo "Код этой игры лицензирован по лицензии MIT."
	echo "Copyright (c) 2024 stuffbymax"
	echo "Вы можете свободно использовать, изменять и распространять его"
	echo "с указанием авторства."
	echo ""
	echo "Полный текст лицензии смотрите по адресу:"
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE"
	echo ""
	echo "Спасибо за игру!"
	read -r -p "Нажмите Enter, чтобы вернуться в главное меню..."
}

# Функция для проверки, жив ли игрок
check_health() {
	if (( health <= 0 )); then
		echo "У вас не осталось здоровья! Отправляем в больницу..."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		hospitalize_player
	fi
}

# Функция для путешествия в новое место
travel_to() {
	local travel_cost="$1"
	# Отображаемое имя локации (можно сделать более сложную логику для перевода ключей)
	local display_location="$2"
	case "$2" in
		"Los Santos") display_location="Лос-Сантос";;
		"San Fierro") display_location="Сан-Фиерро";;
		"Las Venturas") display_location="Лас-Вентурас";;
		"Vice City") display_location="Вайс-Сити";;
		"Liberty City") display_location="Либерти-Сити";;
		*) display_location="$2";; # Оставляем как есть, если нет перевода
	esac
	local internal_location="$2" # Внутреннее имя не меняем

	if (( cash >= travel_cost )); then
		echo "Путешествие в $display_location..."
		play_sfx_mpg "air"

		# --- Анимация перелета (вызов из плагина) ---
		air_travel_animation # Вызов функции из animation.sh
		# --- Конец анимации перелета ---

		cash=$((cash - travel_cost))

		location="$internal_location" # Обновляем внутреннюю переменную
		clear_screen
		echo "Вы прибыли в $display_location."
	else
		echo "Недостаточно денег для путешествия в $display_location."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		clear_screen
	fi
}

# Функция для покупки оружия
buy_guns() {
	local gun_choice
	clear_screen
	echo "Оружейный магазин - Выберите оружие для покупки:"
	echo "1. Пистолет (100$)"
	echo "2. Дробовик (250$)"
	echo "3. ПП (SMG) (500$)"
	echo "4. Винтовка (750$)"
	echo "5. Снайперская винтовка (1000$)"
	echo "6. Назад в главное меню"
	read -r -p "Введите ваш выбор (номер): " gun_choice

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод. Пожалуйста, введите номер из меню."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		return
	}

	case "$gun_choice" in
		1) buy_item "Pistol" 100 "Пистолет";;    # Передаем внутреннее и отображаемое имя
		2) buy_item "Shotgun" 250 "Дробовик";;
		3) buy_item "SMG" 500 "ПП (SMG)";;
		4) buy_item "Rifle" 750 "Винтовка";;
		5) buy_item "Sniper" 1000 "Снайперская винтовка";;
		6) clear_screen;;
		*) echo "Неверный выбор.";;
	esac
}

# Вспомогательная функция для покупки предметов
buy_item() {
	local item_key="$1"       # Внутренний ключ
	local item_cost="$2"
	local item_name_ru="$3"   # Отображаемое имя

	play_sfx_mpg "cash_register"
	buy_animation # Предполагается, что анимация универсальна

	if (( cash >= item_cost )); then
		cash=$((cash - item_cost))
		guns+=("$item_key") # В инвентарь добавляем ключ
		echo "Вы купили $item_name_ru."
		read -r -p "Нажмите Enter, чтобы продолжить..."
	else
		echo "Недостаточно денег, чтобы купить $item_name_ru."
		read -r -p "Нажмите Enter, чтобы продолжить..."
	fi
}

# Функция для отображения инвентаря
show_inventory() {
	clear_screen
	echo "Ваш инвентарь:"
	printf "Деньги: %d долларов\n" "$cash"
	printf "Здоровье: %d%%\n" "$health"
	# Отображение оружия (переводим ключи в названия)
	echo "Оружие:"
	local gun_list_ru=""
	for gun_key in "${guns[@]}"; do
		local gun_name_ru="$gun_key" # По умолчанию ключ
		case "$gun_key" in
			"Pistol") gun_name_ru="Пистолет";;
			"Shotgun") gun_name_ru="Дробовик";;
			"SMG") gun_name_ru="ПП (SMG)";;
			"Rifle") gun_name_ru="Винтовка";;
			"Sniper") gun_name_ru="Снайперская винтовка";;
		esac
		gun_list_ru+="$gun_name_ru "
	done
	printf "  %s\n" "$gun_list_ru"

    # Отображение предметов (переводим ключи в названия)
	echo "Предметы:"
    local item_list_ru=""
	for item_key in "${items[@]}"; do
        local item_name_ru="$item_key" # По умолчанию ключ
		case "$item_key" in
			"Health Pack") item_name_ru="Аптечка";;
            # Добавить другие предметы сюда, если они появятся
		esac
        item_list_ru+="$item_name_ru "
	done
    printf "  %s\n" "$item_list_ru"

	# Отображение наркотиков
	echo "Наркотики: "
	local IFS=$'\n'
	for drug_key in "${!drugs[@]}"; do
        local drug_name_ru="$drug_key"
        case "$drug_key" in
            "Weed") drug_name_ru="Трава";;
            "Cocaine") drug_name_ru="Кокаин";;
            "Heroin") drug_name_ru="Героин";;
            "Meth") drug_name_ru="Мет";;
        esac
		printf "  - %s: %s\n" "$drug_name_ru" "${drugs[$drug_key]}"
	done
	IFS=$' \t\n' # Restore IFS

	# Отображение навыков
	echo "Навыки:"
	local IFS=$'\n'
	for skill_key in "${!skills[@]}"; do
        local skill_name_ru="$skill_key"
        case "$skill_key" in
            "driving") skill_name_ru="Вождение";;
            "strength") skill_name_ru="Сила";;
            "charisma") skill_name_ru="Харизма";;
            "stealth") skill_name_ru="Скрытность";;
            "drug_dealer") skill_name_ru="Торговля наркотиками";;
        esac
		printf "  - %s: %s\n" "$skill_name_ru" "${skills[$skill_key]}"
	done
	IFS=$' \t\n' # Restore IFS
	read -r -p "Нажмите Enter, чтобы вернуться в главное меню."
}

# Функция для работы (упрощенная логика)
work_job() {
	local job_key="$1" # Внутренний ключ работы
	local job_name_ru="$1" # Отображаемое имя по умолчанию
	case "$job_key" in
		"taxi") job_name_ru="таксист";;
		"delivery") job_name_ru="курьер";;
		"mechanic") job_name_ru="механик";;
		"security") job_name_ru="охранник";;
		"performer") job_name_ru="уличный артист";;
	esac

	local earnings
	local min_earnings max_earnings
	local driving_skill=$((skills["driving"] * 5)) #Пример использования навыков

	# Локализация названий городов для расчета заработка
	local current_location_ru="$location"
	case "$location" in
		"Los Santos") current_location_ru="Лос-Сантос";;
		"San Fierro") current_location_ru="Сан-Фиерро";;
		"Las Venturas") current_location_ru="Лас-Вентурас";;
		"Vice City") current_location_ru="Вайс-Сити";;
		"Liberty City") current_location_ru="Либерти-Сити";;
	esac

	case "$location" in
		"Los Santos") min_earnings=20; max_earnings=$((60 + driving_skill));;
		"San Fierro") min_earnings=25; max_earnings=$((70 + driving_skill));;
		"Las Venturas") min_earnings=30; max_earnings=$((90 + driving_skill));;
		"Vice City") min_earnings=15; max_earnings=$((50 + driving_skill));;
		"Liberty City") min_earnings=35; max_earnings=$((100 + driving_skill));;
		*) min_earnings=10; max_earnings=$((40 + driving_skill));; # Значения по умолчанию
	esac

	case "$job_key" in
		"taxi")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))
			play_sfx_mpg "taxi"
			working_animation
			;;
		"delivery")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 10))
			play_sfx_mpg "taxi" # Можно добавить другой звук
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
		*) echo "Неверная работа"; return;;
	esac

	echo "Вы работаете как $job_name_ru в $current_location_ru..."
	read -r -p "Нажмите Enter, чтобы продолжить..."

	cash=$((cash + earnings))
	clear_screen
	printf "Вы заработали %d долларов. Теперь у вас %d долларов.\n" "$earnings" "$cash"
	read -r -p "Нажмите Enter, чтобы продолжить..."
}

# Функция для уличных гонок (отдельная функция)
street_race() {
	working_animation # Можно использовать другую анимацию
	# Локализация названия города
	local current_location_ru="$location"
	case "$location" in
		"Los Santos") current_location_ru="Лос-Сантос";;
		"San Fierro") current_location_ru="Сан-Фиерро";;
		"Las Venturas") current_location_ru="Лас-Вентурас";;
		"Vice City") current_location_ru="Вайс-Сити";;
		"Liberty City") current_location_ru="Либерти-Сити";;
	esac
	echo "Вы участвуете в уличной гонке в $current_location_ru..."
	read -r -p "Нажмите Enter, чтобы продолжить..."
	local winnings
	local damage
	local driving_skill=$((skills["driving"] * 5))
	local win_chance=$((50 + driving_skill)) # Влияние на шанс победы

	if (( RANDOM % 100 < win_chance )); then
		winnings=$((RANDOM % 201 + 100))
		cash=$((cash + winnings))
		damage=$((RANDOM % 21 + 10))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Ваш бронежилет уменьшил урон!"
			body_armor_equipped=false
		fi
		health=$((health - damage))
		check_health
		clear_screen
		printf "Вы выиграли уличную гонку и получили %d долларов, но потеряли %d%% здоровья. Теперь у вас %d долларов и %d%% здоровья.\n" "$winnings" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Звук победы
		read -r -p "Нажмите Enter, чтобы продолжить..."
	else
		damage=$((RANDOM % 41 + 20))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Ваш бронежилет уменьшил урон!"
			body_armor_equipped=false
		fi
		health=$((health - damage))
		check_health
		clear_screen
		printf "Вы проиграли уличную гонку и получили %d%% урона. Теперь у вас %d%% здоровья.\n" "$damage" "$health"
		play_sfx_mpg "lose" # Звук проигрыша
		read -r -p "Нажмите Enter, чтобы продолжить..."
	fi
}

# Функция для использования оружия в заданиях - сейчас не используется, но оставлена для будущего.
use_guns() {
	# Перевод имени оружия для сообщения
	local gun_key="$1"
	local gun_name_ru="$gun_key"
	case "$gun_key" in
		"Pistol") gun_name_ru="Пистолет";;
		"Shotgun") gun_name_ru="Дробовик";;
		"SMG") gun_name_ru="ПП (SMG)";;
		"Rifle") gun_name_ru="Винтовка";;
		"Sniper") gun_name_ru="Снайперская винтовка";;
	esac

	# Проверка наличия оружия по ключу
	local found=false
	for owned_gun in "${guns[@]}"; do
		if [[ "$owned_gun" == "$gun_key" ]]; then
			found=true
			break
		fi
	done

	if $found; then
		echo "Вы использовали $gun_name_ru для этого задания."
		play_sfx_mpg "gun_shot"
		read -r -p "Нажмите Enter, чтобы продолжить..."
	else
		echo "У вас нет $gun_name_ru. Задание провалено."
		read -r -p "Нажмите Enter, чтобы продолжить..."
	fi
}


# Функция для посещения больницы
visit_hospital() {
	local hospital_choice
	clear_screen
	echo "Услуги больницы:"
	echo "1. Базовое лечение (50$) - Полное исцеление"
	echo "2. Продвинутое лечение (100$) - Полное исцеление + 10% бонус к здоровью"
	echo "3. Купить аптечку (30$) - Восстанавливает 25% здоровья"
	echo "4. Купить бронежилет (75$) - Уменьшает урон на 50% в следующей стычке"
	echo "5. Назад в главное меню"
	read -r -p "Введите ваш выбор (номер): " hospital_choice

	[[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод. Пожалуйста, введите номер из меню."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		return
	}

	case "$hospital_choice" in
		1) buy_hospital_item 50 "basic_treatment" "Базовое лечение";;
		2) buy_hospital_item 100 "advanced_treatment" "Продвинутое лечение";;
		3) buy_hospital_item 30 "health_pack" "Аптечка";;
		4) buy_hospital_item 75 "body_armor" "Бронежилет";;
		5) clear_screen;;
		*) echo "Неверный выбор.";;
	esac
}

# Вспомогательная функция для покупки предметов в больнице
buy_hospital_item() {
	local item_cost="$1"
	local item_key="$2"
	local item_name_ru="$3"

	if (( cash >= item_cost )); then
		cash=$((cash - item_cost))
		case "$item_key" in
			"basic_treatment")
				health=100
				echo "Вы получили базовое лечение и полностью исцелены."
				play_sfx_mpg "heal" # Звук лечения
				read -r -p "Нажмите Enter, чтобы продолжить..."
				;;
			"advanced_treatment")
				health=$((health + 10)) # Лечение до 100% происходит ниже
				(( health > 110 )) && health=110 # Временно позволяем > 100 для бонуса
                health=100 # Ограничиваем 100 после расчета
				# Доп. логика: Можно сделать макс. здоровье 110, если нужно
				echo "Вы получили продвинутое лечение, полностью исцелены и получили бонус к здоровью."
				play_sfx_mpg "heal" # Звук лечения
				read -r -p "Нажмите Enter, чтобы продолжить..."
				;;
			"health_pack")
				items+=("Health Pack") # Добавляем ключ
				echo "Вы купили Аптечку."
				play_sfx_mpg "item_buy" # Звук покупки предмета
				read -r -p "Нажмите Enter, чтобы продолжить..."
				;;
			"body_armor")
				body_armor_equipped=true
				echo "Вы купили Бронежилет."
				play_sfx_mpg "item_buy" # Звук покупки предмета
				read -r -p "Нажмите Enter, чтобы продолжить..."
				;;
		esac
	else
		echo "Недостаточно денег для '$item_name_ru'."
		read -r -p "Нажмите Enter, чтобы продолжить..."
	fi
}


# Функция для ограбления магазина
rob_store() {
	robbing_animation
	# Локализация названия города
	local current_location_ru="$location"
	case "$location" in
		"Los Santos") current_location_ru="Лос-Сантос";;
		"San Fierro") current_location_ru="Сан-Фиерро";;
		"Las Venturas") current_location_ru="Лас-Вентурас";;
		"Vice City") current_location_ru="Вайс-Сити";;
		"Liberty City") current_location_ru="Либерти-Сити";;
	esac
	echo "Пытаемся ограбить магазин в $current_location_ru..."

	local stealth_skill=$((skills["stealth"] * 5)) # Базовый навык скрытности
	local gun_bonus=0 # Инициализация бонуса от оружия

	if (( ${#guns[@]} > 0 )); then
		echo "Хотите использовать оружие? (y/n - д/н)"
		read -r use_gun

	if [[ "$use_gun" == "y" || "$use_gun" == "д" || "$use_gun" == "Y" || "$use_gun" == "Д" ]]; then
			echo "Какое оружие использовать? (Введите название)"
			# Отображение доступного оружия на русском
			local available_guns_ru=""
			for gun_key in "${guns[@]}"; do
				local gun_name_ru="$gun_key"
                case "$gun_key" in
                    "Pistol") gun_name_ru="Пистолет";;
                    "Shotgun") gun_name_ru="Дробовик";;
                    "SMG") gun_name_ru="ПП (SMG)";;
                    "Rifle") gun_name_ru="Винтовка";;
                    "Sniper") gun_name_ru="Снайперская винтовка";;
                esac
				available_guns_ru+="$gun_name_ru "
			done
			echo "Доступное оружие: $available_guns_ru"
			read -r chosen_gun_input # Читаем ввод пользователя

            # Ищем ключ оружия по введенному русскому названию
			local chosen_gun_key=""
            gun_found=false
            case "$chosen_gun_input" in # Проверяем основные варианты
                 "Пистолет"|"пистолет") chosen_gun_key="Pistol"; gun_found=true;;
                 "Дробовик"|"дробовик") chosen_gun_key="Shotgun"; gun_found=true;;
                 "ПП"|"пп"|"SMG"|"smg") chosen_gun_key="SMG"; gun_found=true;;
                 "Винтовка"|"винтовка") chosen_gun_key="Rifle"; gun_found=true;;
                 "Снайперская винтовка"|"снайперка") chosen_gun_key="Sniper"; gun_found=true;;
            esac

            # Дополнительная проверка, есть ли найденный ключ у игрока
            if $gun_found; then
                local actually_owns_gun=false
                for owned_gun in "${guns[@]}"; do
                    if [[ "$owned_gun" == "$chosen_gun_key" ]]; then
                        actually_owns_gun=true
                        break
                    fi
                done
                if ! $actually_owns_gun; then
                    gun_found=false # Сбрасываем флаг, если оружия нет
                fi
            fi


			if $gun_found; then
				# Получаем русское имя для вывода
				local chosen_gun_name_ru="$chosen_gun_input" # Используем ввод, т.к. он уже русский
				echo "Вы использовали $chosen_gun_name_ru!"
				play_sfx_mpg "gun_shot"  # Звук выстрела

				# --- Применение бонуса от оружия ---
				if [[ -v "gun_attributes[$chosen_gun_key]" ]]; then
					eval "${gun_attributes[$chosen_gun_key]}" # Извлекаем строку атрибутов
					gun_bonus=$success_bonus # Получаем бонус к успеху
					stealth_skill=$((stealth_skill + gun_bonus)) # Применяем бонус
					echo "$chosen_gun_name_ru дает вам +${gun_bonus}% к шансу успеха."
				else
					echo "Атрибуты для $chosen_gun_name_ru не определены (ошибка скрипта)."
				fi
				# --- Конец бонуса от оружия ---
			else
				echo "У вас нет такого оружия!"
			fi
		else
			echo "Действуем без оружия."
		fi
	else
		echo "У вас нет оружия!"
	fi

	read -r -p "Нажмите Enter, чтобы продолжить..."

	local loot
	local damage
	local fine
	if (( RANDOM % 100 < stealth_skill )); then
		loot=$((RANDOM % 201 + 100))
		cash=$((cash + loot))

		damage=$((RANDOM % 31 + 10)) # Урон получаем ДО проверки брони
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Ваш бронежилет уменьшил урон!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Вы успешно ограбили магазин и получили %d долларов, но потеряли %d%% здоровья. Теперь у вас %d долларов и %d%% здоровья.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "cash_register"
		read -r -p "Нажмите Enter, чтобы продолжить..."
	else
		fine=$((RANDOM % 51 + 25))
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0 # Не уходим в минус
		clear_screen
		printf "Вас поймали и оштрафовали на %d долларов. Теперь у вас %d долларов.\n" "$fine" "$cash"
		play_sfx_mpg "lose"   # Звук проигрыша
		read -r -p "Нажмите Enter, чтобы продолжить..."
	fi
}


# Функция для участия в ограблении (крупном)
heist() {
	heist_animation
	# Локализация названия города
	local current_location_ru="$location"
	case "$location" in
		"Los Santos") current_location_ru="Лос-Сантос";;
		"San Fierro") current_location_ru="Сан-Фиерро";;
		"Las Venturas") current_location_ru="Лас-Вентурас";;
		"Vice City") current_location_ru="Вайс-Сити";;
		"Liberty City") current_location_ru="Либерти-Сити";;
	esac
	echo "Планируем ограбление в $current_location_ru..."

	local stealth_skill=$((skills["stealth"] * 5)) # Базовый навык скрытности
	local gun_bonus=0 # Инициализация бонуса от оружия

	if (( ${#guns[@]} > 0 )); then
		echo "Хотите использовать оружие? (y/n - д/н)"
		read -r use_gun

		if [[ "$use_gun" == "y" || "$use_gun" == "д" || "$use_gun" == "Y" || "$use_gun" == "Д" ]]; then
			echo "Какое оружие использовать? (Введите название)"
			# Отображение доступного оружия на русском
			local available_guns_ru=""
			for gun_key in "${guns[@]}"; do
				local gun_name_ru="$gun_key"
                case "$gun_key" in
                    "Pistol") gun_name_ru="Пистолет";;
                    "Shotgun") gun_name_ru="Дробовик";;
                    "SMG") gun_name_ru="ПП (SMG)";;
                    "Rifle") gun_name_ru="Винтовка";;
                    "Sniper") gun_name_ru="Снайперская винтовка";;
                esac
				available_guns_ru+="$gun_name_ru "
			done
			echo "Доступное оружие: $available_guns_ru"
			read -r chosen_gun_input

            # Поиск ключа оружия по русскому названию
			local chosen_gun_key=""
            gun_found=false
            case "$chosen_gun_input" in
                 "Пистолет"|"пистолет") chosen_gun_key="Pistol"; gun_found=true;;
                 "Дробовик"|"дробовик") chosen_gun_key="Shotgun"; gun_found=true;;
                 "ПП"|"пп"|"SMG"|"smg") chosen_gun_key="SMG"; gun_found=true;;
                 "Винтовка"|"винтовка") chosen_gun_key="Rifle"; gun_found=true;;
                 "Снайперская винтовка"|"снайперка") chosen_gun_key="Sniper"; gun_found=true;;
            esac

            # Проверка владения оружием
            if $gun_found; then
                local actually_owns_gun=false
                for owned_gun in "${guns[@]}"; do
                    if [[ "$owned_gun" == "$chosen_gun_key" ]]; then
                        actually_owns_gun=true
                        break
                    fi
                done
                if ! $actually_owns_gun; then
                    gun_found=false
                fi
            fi

			if $gun_found; then
                local chosen_gun_name_ru="$chosen_gun_input"
				echo "Вы использовали $chosen_gun_name_ru!"
				play_sfx_mpg "gun_shot"  # Звук выстрела

				# --- Логика бонуса от оружия ---
				if [[ -v "gun_attributes[$chosen_gun_key]" ]]; then
					eval "${gun_attributes[$chosen_gun_key]}"
					gun_bonus=$success_bonus
					stealth_skill=$((stealth_skill + gun_bonus))
					echo "$chosen_gun_name_ru дает вам +${gun_bonus}% к шансу успеха."
				else
					echo "Атрибуты для $chosen_gun_name_ru не определены (ошибка скрипта)."
				fi
				# --- Конец логики бонуса от оружия ---

			else
				echo "У вас нет такого оружия!"
			fi
		else
			echo "Действуем без оружия."
		fi
	else
		echo "У вас нет оружия!"
	fi

	read -r -p "Нажмите Enter, чтобы продолжить..."

	local loot
	local damage
	local fine
	if (( RANDOM % 100 < stealth_skill )); then
		loot=$((RANDOM % 501 + 200))
		cash=$((cash + loot))

        damage=$((RANDOM % 51 + 20))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Ваш бронежилет уменьшил урон!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Ограбление прошло успешно! Вы получили %d долларов, но потеряли %d%% здоровья. Теперь у вас %d долларов и %d%% здоровья.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Другой звук для успеха?
		read -r -p "Нажмите Enter, чтобы продолжить..."
	else
		fine=$((RANDOM % 101 + 50))
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0

		clear_screen
		printf "Ограбление провалилось, вас поймали, и вы потеряли %d долларов. Теперь у вас %d долларов.\n" "$fine" "$cash"
		play_sfx_mpg "lose"  # Звук проигрыша
		read -r -p "Нажмите Enter, чтобы продолжить..."
	fi
}

# Функция для войн банд
gang_war() {
	# Проверка наличия оружия
	if (( ${#guns[@]} == 0 )); then
		echo "Вы не можете начать войну банд без оружия!"
		read -r -p "Нажмите Enter, чтобы продолжить..."
		return
	fi

	gang_war_animation
	# Локализация названия города
	local current_location_ru="$location"
	case "$location" in
		"Los Santos") current_location_ru="Лос-Сантос";;
		"San Fierro") current_location_ru="Сан-Фиерро";;
		"Las Venturas") current_location_ru="Лас-Вентурас";;
		"Vice City") current_location_ru="Вайс-Сити";;
		"Liberty City") current_location_ru="Либерти-Сити";;
	esac
	echo "Начинаем войну банд в $current_location_ru..."

	local strength_skill=$((skills["strength"] * 5)) # Базовый навык силы
	local gun_bonus=0 # Инициализация бонуса от оружия

	if (( ${#guns[@]} > 0 )); then
		echo "Хотите использовать оружие? (y/n - д/н)"
		read -r use_gun

		if [[ "$use_gun" == "y" || "$use_gun" == "д" || "$use_gun" == "Y" || "$use_gun" == "Д" ]]; then
			echo "Какое оружие использовать? (Введите название)"
			# Отображение доступного оружия на русском
			local available_guns_ru=""
			for gun_key in "${guns[@]}"; do
				local gun_name_ru="$gun_key"
                case "$gun_key" in
                    "Pistol") gun_name_ru="Пистолет";;
                    "Shotgun") gun_name_ru="Дробовик";;
                    "SMG") gun_name_ru="ПП (SMG)";;
                    "Rifle") gun_name_ru="Винтовка";;
                    "Sniper") gun_name_ru="Снайперская винтовка";;
                esac
				available_guns_ru+="$gun_name_ru "
			done
			echo "Доступное оружие: $available_guns_ru"
			read -r chosen_gun_input

            # Поиск ключа оружия по русскому названию
			local chosen_gun_key=""
            gun_found=false
            case "$chosen_gun_input" in
                 "Пистолет"|"пистолет") chosen_gun_key="Pistol"; gun_found=true;;
                 "Дробовик"|"дробовик") chosen_gun_key="Shotgun"; gun_found=true;;
                 "ПП"|"пп"|"SMG"|"smg") chosen_gun_key="SMG"; gun_found=true;;
                 "Винтовка"|"винтовка") chosen_gun_key="Rifle"; gun_found=true;;
                 "Снайперская винтовка"|"снайперка") chosen_gun_key="Sniper"; gun_found=true;;
            esac

            # Проверка владения оружием
            if $gun_found; then
                local actually_owns_gun=false
                for owned_gun in "${guns[@]}"; do
                    if [[ "$owned_gun" == "$chosen_gun_key" ]]; then
                        actually_owns_gun=true
                        break
                    fi
                done
                if ! $actually_owns_gun; then
                    gun_found=false
                fi
            fi

			if $gun_found; then
                local chosen_gun_name_ru="$chosen_gun_input"
				echo "Вы использовали $chosen_gun_name_ru!"
				play_sfx_mpg "gun_shot"  # Звук выстрела

				# --- Логика бонуса от оружия ---
				if [[ -v "gun_attributes[$chosen_gun_key]" ]]; then
					eval "${gun_attributes[$chosen_gun_key]}"
					gun_bonus=$success_bonus
					strength_skill=$((strength_skill + gun_bonus)) # Используем strength_skill
					echo "$chosen_gun_name_ru дает вам +${gun_bonus}% к шансу успеха."
				else
					echo "Атрибуты для $chosen_gun_name_ru не определены (ошибка скрипта)."
				fi
				# --- Конец логики бонуса от оружия ---

			else
				echo "У вас нет такого оружия!"
			fi
		else
			echo "Действуем без оружия."
		fi
	else
		# Эта ветка не должна сработать из-за проверки в начале функции
        echo "У вас нет оружия!"
	fi

	read -r -p "Нажмите Enter, чтобы продолжить..."

	local loot
	local damage
	local fine

	if (( RANDOM % 100 < strength_skill )); then
		loot=$((RANDOM % 301 + 100))
		cash=$((cash + loot))

        damage=$((RANDOM % 51 + 30))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Ваш бронежилет уменьшил урон!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Вы выиграли войну банд и получили %d долларов, но потеряли %d%% здоровья. Теперь у вас %d долларов и %d%% здоровья.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Звук победы в войне банд?
		read -r -p "Нажмите Enter, чтобы продолжить..."
	else
		fine=$((RANDOM % 151 + 50))
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
		damage=$((RANDOM % 41 + 20))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Ваш бронежилет уменьшил урон!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Вы проиграли войну банд, были оштрафованы на %d долларов и потеряли %d%% здоровья. Теперь у вас %d долларов и %d%% здоровья.\n" "$fine" "$damage" "$cash" "$health"
		play_sfx_mpg "lose"  # Звук проигрыша
		read -r -p "Нажмите Enter, чтобы продолжить..."
	fi
}


# Функция для угона автомобиля
carjack() {
	local success_chance=0 # Инициализация шанса успеха здесь
	# Проверка наличия оружия
	if (( ${#guns[@]} == 0 )); then
		# Уведомление игрока
		echo "У вас нет оружия, придется полагаться на навыки. Угнать машину будет сложнее."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		success_chance=$((success_chance - 20))  # Уменьшение шанса успеха без оружия
	fi

	# Проверка, выбрал ли игрок использовать оружие
	if (( ${#guns[@]} > 0 )); then
		# Спрашиваем игрока
		echo "Хотите использовать оружие? (y/n - д/н)"
		read -r use_gun

		if [[ "$use_gun" == "y" || "$use_gun" == "д" || "$use_gun" == "Y" || "$use_gun" == "Д" ]]; then
			# Список доступного оружия
			echo "Какое оружие использовать? (Введите название)"
			local available_guns_ru=""
			for gun_key in "${guns[@]}"; do
				local gun_name_ru="$gun_key"
                case "$gun_key" in
                    "Pistol") gun_name_ru="Пистолет";;
                    "Shotgun") gun_name_ru="Дробовик";;
                    "SMG") gun_name_ru="ПП (SMG)";;
                    "Rifle") gun_name_ru="Винтовка";;
                    "Sniper") gun_name_ru="Снайперская винтовка";;
                esac
				available_guns_ru+="$gun_name_ru "
			done
			echo "Доступное оружие: $available_guns_ru"
			read -r chosen_gun_input

			# Поиск ключа оружия по русскому названию
			local chosen_gun_key=""
            gun_found=false
            case "$chosen_gun_input" in
                 "Пистолет"|"пистолет") chosen_gun_key="Pistol"; gun_found=true;;
                 "Дробовик"|"дробовик") chosen_gun_key="Shotgun"; gun_found=true;;
                 "ПП"|"пп"|"SMG"|"smg") chosen_gun_key="SMG"; gun_found=true;;
                 "Винтовка"|"винтовка") chosen_gun_key="Rifle"; gun_found=true;;
                 "Снайперская винтовка"|"снайперка") chosen_gun_key="Sniper"; gun_found=true;;
            esac

            # Проверка владения оружием
            if $gun_found; then
                local actually_owns_gun=false
                for owned_gun in "${guns[@]}"; do
                    if [[ "$owned_gun" == "$chosen_gun_key" ]]; then
                        actually_owns_gun=true
                        break
                    fi
                done
                if ! $actually_owns_gun; then
                    gun_found=false
                fi
            fi


			if $gun_found; then
                local chosen_gun_name_ru="$chosen_gun_input"
				echo "Вы использовали $chosen_gun_name_ru!"
				play_sfx_mpg "gun_shot"  # Звук выстрела
				local gun_bonus=0 # Инициализация бонуса здесь

				# --- Логика бонуса от оружия ---
				if [[ -v "gun_attributes[$chosen_gun_key]" ]]; then
					eval "${gun_attributes[$chosen_gun_key]}"
					gun_bonus=$success_bonus
					success_chance=$((success_chance + gun_bonus)) # Применяем к шансу успеха
					echo "$chosen_gun_name_ru дает вам +${gun_bonus}% к шансу успеха."
				else
					echo "Атрибуты для $chosen_gun_name_ru не определены (ошибка скрипта)."
				fi
				# --- Конец логики бонуса от оружия ---

			else
				echo "У вас нет такого оружия!"
				# Продолжаем без оружия, если выбранного нет
				echo "Действуем без оружия."
				success_chance=$((success_chance - 15))  # Уменьшаем шанс (-15, т.к. -20 уже могло быть)
			fi
		else
			# Если игрок решил не использовать оружие
			echo "Действуем без оружия."
			success_chance=$((success_chance - 15))  # Уменьшаем шанс (-15)
		fi
	fi

	# Запуск анимации угона после решения
	carjacking_animation
	# Локализация названия города
	local current_location_ru="$location"
	case "$location" in
		"Los Santos") current_location_ru="Лос-Сантос";;
		"San Fierro") current_location_ru="Сан-Фиерро";;
		"Las Venturas") current_location_ru="Лас-Вентурас";;
		"Vice City") current_location_ru="Вайс-Сити";;
		"Liberty City") current_location_ru="Либерти-Сити";;
	esac
	echo "Пытаемся угнать транспорт в $current_location_ru..."
	read -r -p "Нажмите Enter, чтобы продолжить..."

	local loot
	local damage
	local fine
	local driving_skill=$((skills["driving"] * 5))
	local stealth_skill=$((skills["stealth"] * 5))
    # Базовый шанс от навыков + модификатор оружия/отсутствия оружия
	success_chance=$(( 40 + driving_skill + stealth_skill + success_chance )) # Базовый шанс 40% + навыки + бонусы/штрафы
    (( success_chance < 5 )) && success_chance=5 # Минимальный шанс
    (( success_chance > 95 )) && success_chance=95 # Максимальный шанс

	# Теперь вычисляем успех
	if (( RANDOM % 100 < success_chance )); then
		loot=$((RANDOM % 201 + 50))
		cash=$((cash + loot))

		damage=$((RANDOM % 21 + 10))
		if [[ "$body_armor_equipped" == true ]]; then
			damage=$((damage / 2))
			echo "Ваш бронежилет уменьшил урон!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "Вы успешно угнали транспорт и получили %d долларов, но потеряли %d%% здоровья.\nТеперь у вас %d долларов и %d%% здоровья.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "car_start"  # Звук угона
		read -r -p "Нажмите Enter, чтобы продолжить..."
	else
		fine=$((RANDOM % 76 + 25))
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
		clear_screen
		printf "Вас поймали и оштрафовали на %d долларов. Теперь у вас %d долларов.\n" "$fine" "$cash"
		play_sfx_mpg "lose"  # Звук проигрыша
		read -r -p "Нажмите Enter, чтобы продолжить..."
	fi
}


# Функция для обработки госпитализации после смерти
hospitalize_player() {
	clear_screen
	echo "Вы были госпитализированы и проходите лечение..."
	read -r -p "Нажмите Enter, чтобы продолжить..."
	health=100
	clear_screen
    local treatment_cost=200
	echo "Вы полностью исцелены, но потеряли $treatment_cost долларов за лечение."
	cash=$((cash - treatment_cost))
	(( cash < 0 )) && cash=0 # Не уходим в минус
	read -r -p "Нажмите Enter, чтобы продолжить..."
	clear_screen
}

# Функция для найма проститутки
hire_hooker() {
	# Локализация названия города
	local current_location_ru="$location"
	case "$location" in
		"Los Santos") current_location_ru="Лос-Сантос";;
		"San Fierro") current_location_ru="Сан-Фиерро";;
		"Las Venturas") current_location_ru="Лас-Вентурас";;
		"Vice City") current_location_ru="Вайс-Сити";;
		"Liberty City") current_location_ru="Либерти-Сити";;
	esac
	echo "Вы ищете проститутку в $current_location_ru..."
	read -r -p "Нажмите Enter, чтобы продолжить..."
	local hooker_cost
	local health_gain
	local charisma_skill=$(( skills["charisma"] * 2 ))  # Влияние на цену

	# Расчет стоимости с учетом харизмы
	(( charisma_skill > 40 )) && charisma_skill=40 # Ограничиваем скидку от харизмы
	local min_cost=$(( 50 - charisma_skill ))
	local max_cost=$(( 101 - charisma_skill ))
	(( min_cost < 10 )) && min_cost=10 # Минимальная цена
	(( max_cost <= min_cost )) && max_cost=$(( min_cost + 20 )) # Гарантия диапазона
	hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))

	health_gain=$(( RANDOM % 21 + 10 )) # Прирост здоровья

	if (( cash >= hooker_cost )); then
        cash=$(( cash - hooker_cost ))
        health=$(( health + health_gain ))
        (( health > 100 )) && health=100 # Не превышаем 100%
        clear_screen
        printf "Вы наняли проститутку за %d долларов и получили %d%% здоровья.\nТеперь у вас %d долларов и %d%% здоровья.\n" \
        "$hooker_cost" "$health_gain" "$cash" "$health"
        play_sfx_mpg "hooker"  # Звук проститутки?
        read -r -p "Нажмите Enter, чтобы продолжить..."
    else
        clear_screen
        echo "Недостаточно денег, чтобы нанять проститутку."
        read -r -p "Нажмите Enter, чтобы продолжить..."
	fi

    clear_screen # Очищаем экран в любом случае после действия
}


# Централизованная функция для сделок с наркотиками
drug_transaction() {
	local action="$1" # "buy" или "sell"
	local drug_key="$2" # Внутренний ключ
	local drug_price="$3"
	local drug_amount="$4"
	local cost income selling_price
	local drug_dealer_skill=$((skills["drug_dealer"]))

    # Получаем русское название наркотика
    local drug_name_ru="$drug_key"
    case "$drug_key" in
        "Weed") drug_name_ru="Трава";;
        "Cocaine") drug_name_ru="Кокаин";;
        "Heroin") drug_name_ru="Героин";;
        "Meth") drug_name_ru="Мет";;
    esac

	if [[ "$action" == "buy" ]]; then
		cost=$((drug_price * drug_amount))
		if (( cash >= cost )); then
			drug_transaction_animation
			cash=$((cash - cost))
			# Увеличиваем количество наркотика по ключу
            drugs["$drug_key"]=$(( ${drugs["$drug_key"]:-0} + drug_amount )) # :-0 для инициализации, если ключа нет
			printf "Вы купили %s ед. %s.\n" "$drug_amount" "$drug_name_ru"
			play_sfx_mpg "cash_register"
			return 0
		else
			echo "Недостаточно денег, чтобы купить $drug_name_ru."
			return 1
		fi
	elif [[ "$action" == "sell" ]]; then
		# Проверяем наличие наркотика по ключу
		if [[ -v "drugs[$drug_key]" ]] && (( ${drugs["$drug_key"]} >= drug_amount )); then
			drug_transaction_animation

			# Корректировка цены продажи на основе навыка
			local price_modifier=$((drug_dealer_skill * 2)) # Пример: 2% увеличение за очко навыка
			local adjusted_price=$((drug_price + (drug_price * price_modifier / 100)))

			income=$((adjusted_price * drug_amount))
			cash=$((cash + income))
			drugs["$drug_key"]=$((drugs["$drug_key"] - drug_amount))
            # Удаляем ключ, если количество стало 0
            # (( drugs["$drug_key"] == 0 )) && unset drugs["$drug_key"] # Пока не будем удалять

			printf "Вы продали %s ед. %s за %d долларов (с учетом вашего навыка торговли наркотиками).\n" "$drug_amount" "$drug_name_ru" "$income"
			play_sfx_mpg "cash_register"
			# Увеличение навыка торговли наркотиками
			skills["drug_dealer"]=$((drug_dealer_skill + 1)) # Простое увеличение
			echo "Ваш навык торговли наркотиками увеличился!"
			return 0
		else
			echo "Недостаточно %s для продажи." "$drug_name_ru"
			return 1
		fi
	else
		echo "Неверное действие: $action"
		return 1
	fi
}

# Функция покупки наркотиков
buy_drugs() {
	local drug_choice drug_amount

	clear_screen
	echo "Наркодилер - Выберите наркотик для покупки:"
	echo "1. Трава (10$/ед.)"
	echo "2. Кокаин (50$/ед.)"
	echo "3. Героин (100$/ед.)"
	echo "4. Мет (75$/ед.)"
	echo "5. Назад в главное меню"
	read -r -p "Введите ваш выбор (номер): " drug_choice

	[[ ! "$drug_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод. Пожалуйста, введите номер из меню."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		return
	}
    # Выход из меню
    if [[ "$drug_choice" == 5 ]]; then
        clear_screen
        return
    fi

	read -r -p "Введите количество для покупки: " drug_amount
	[[ ! "$drug_amount" =~ ^[0-9]+$ ]] || (( drug_amount <= 0 )) && {
		echo "Неверный ввод. Пожалуйста, введите положительное число."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		return
	}
	case "$drug_choice" in
		1) drug_transaction "buy" "Weed" 10 "$drug_amount";;
		2) drug_transaction "buy" "Cocaine" 50 "$drug_amount";;
		3) drug_transaction "buy" "Heroin" 100 "$drug_amount";;
		4) drug_transaction "buy" "Meth" 75 "$drug_amount";;
		# 5) обрабатывается выше
		*) echo "Неверный выбор."; read -r -p "Нажмите Enter, чтобы продолжить..."; return;;
	esac
	read -r -p "Нажмите Enter, чтобы продолжить..."
}

# Функция продажи наркотиков
sell_drugs() {
	local drug_choice drug_amount
	clear_screen
	echo "Наркодилер - Выберите наркотик для продажи:"
	# Отображаем только те, что есть у игрока
    local available_drugs_menu=()
    local drug_keys_map=() # Карта для связи номера меню с ключом
    local menu_index=1

    # Порядок важен для нумерации меню
    local drug_order=("Weed" "Cocaine" "Heroin" "Meth")
    local drug_names_ru=("Трава" "Кокаин" "Героин" "Мет")
    local drug_sell_prices=(15 75 150 100) # Базовые цены продажи

    for i in "${!drug_order[@]}"; do
        local key="${drug_order[$i]}"
        if [[ -v "drugs[$key]" ]] && (( ${drugs["$key"]} > 0 )); then
            available_drugs_menu+=("$menu_index. ${drug_names_ru[$i]} (у вас: ${drugs[$key]})")
            drug_keys_map[$menu_index]="$key"
            drug_prices_map[$menu_index]="${drug_sell_prices[$i]}"
            ((menu_index++))
        fi
    done

    if (( ${#available_drugs_menu[@]} == 0 )); then
        echo "У вас нет наркотиков для продажи."
        echo "$menu_index. Назад в главное меню"
        read -r -p "Введите ваш выбор (номер): " drug_choice
        clear_screen
        return
    fi

    # Выводим меню
    for item in "${available_drugs_menu[@]}"; do
        echo "$item"
    done
	echo "$menu_index. Назад в главное меню"
	read -r -p "Введите ваш выбор (номер): " drug_choice

	[[ ! "$drug_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод. Пожалуйста, введите номер из меню."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		return
	}

    # Проверяем выход из меню
    if (( drug_choice == menu_index )); then
        clear_screen; return
    fi

    # Проверяем, есть ли такой номер в карте
    if [[ ! -v "drug_keys_map[$drug_choice]" ]]; then
        echo "Неверный выбор.";
        read -r -p "Нажмите Enter, чтобы продолжить..."
        return
    fi

    local selected_drug_key="${drug_keys_map[$drug_choice]}"
    local selected_drug_price="${drug_prices_map[$drug_choice]}"
    local selected_drug_name_ru="" # Получим имя из ключа
     case "$selected_drug_key" in
        "Weed") selected_drug_name_ru="Трава";;
        "Cocaine") selected_drug_name_ru="Кокаин";;
        "Heroin") selected_drug_name_ru="Героин";;
        "Meth") selected_drug_name_ru="Мет";;
    esac

	read -r -p "Введите количество '$selected_drug_name_ru' для продажи (макс: ${drugs[$selected_drug_key]}): " drug_amount
	[[ ! "$drug_amount" =~ ^[0-9]+$ ]] || (( drug_amount <= 0 )) && {
		echo "Неверный ввод. Пожалуйста, введите положительное число."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		return
	}

    # Проверяем, не пытается ли продать больше, чем есть
    if (( drug_amount > ${drugs[$selected_drug_key]} )); then
        echo "Нельзя продать больше, чем у вас есть ($selected_drug_name_ru: ${drugs[$selected_drug_key]})."
        read -r -p "Нажмите Enter, чтобы продолжить..."
        return
    fi

    # Выполняем транзакцию
	drug_transaction "sell" "$selected_drug_key" "$selected_drug_price" "$drug_amount"

	read -r -p "Нажмите Enter, чтобы продолжить..."
}


# Функция для воспроизведения музыки
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
		echo "Выберите трек для воспроизведения:"
		for i in "${!music_files[@]}"; do
            # Показываем только имя файла без пути
			printf "%d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"
		done
		echo "Нажмите 'q' или выберите опцию ниже, чтобы остановить музыку"
		printf "%d. Назад в главное меню\n" $(( ${#music_files[@]} + 1 ))
		read -r -n 1 -p "Ваш выбор: " music_choice # Читаем 1 символ без Enter
        echo "" # Перевод строки после read -n 1

        if [[ "$music_choice" == "q" || "$music_choice" == "Q" || "$music_choice" == "й" || "$music_choice" == "Й" ]]; then
            pkill mpg123 # Остановить воспроизведение
            echo "Музыка остановлена."
            sleep 1
            continue # Возврат к меню выбора музыки
        fi

		if ! [[ "$music_choice" =~ ^[0-9]+$ ]]; then
			echo "Неверный ввод. Пожалуйста, введите номер."
			sleep 2
			continue # Возврат к меню выбора музыки
		fi

		if (( music_choice > 0 && music_choice <= ${#music_files[@]} )); then
			local selected_track="${music_files[$((music_choice - 1))]}"
			if [[ -f "$selected_track" ]]; then
				pkill mpg123 # Останавливаем предыдущую, если играла
				echo "Воспроизведение: $(basename "$selected_track")"
				mpg123 -q "$selected_track" & # Запускаем в фоне
                sleep 1 # Небольшая пауза
			else
				echo "Ошибка: Музыкальный файл '$selected_track' не найден."
				sleep 2
			fi
		elif (( music_choice == ${#music_files[@]} + 1 )); then
			pkill mpg123 # Останавливаем музыку при выходе
			clear_screen
			break  # Выход из меню музыки
		else
			echo "Неверный выбор."
			sleep 2
		fi
	done
}


# Сохранение состояния игры в файл
save_game() {
    # Создаем директорию, если её нет
    mkdir -p "$SAVE_DIR"

	echo "$player_name" > "$SAVE_DIR/player_name.sav"
	echo "$location" > "$SAVE_DIR/location.sav"
	echo "$cash" > "$SAVE_DIR/cash.sav"
	echo "$health" > "$SAVE_DIR/health.sav"
	printf '%s\n' "${guns[@]}" > "$SAVE_DIR/guns.sav"
	printf '%s\n' "${items[@]}" > "$SAVE_DIR/items.sav"
	# Сохраняем наркотики
	: > "$SAVE_DIR/drugs.sav" # Очищаем файл перед записью
	for key in "${!drugs[@]}"; do
        # Сохраняем только если количество > 0 (опционально)
        # if (( ${drugs[$key]} > 0 )); then
		    printf "%s %s\n" "$key" "${drugs[$key]}" >> "$SAVE_DIR/drugs.sav"
        # fi
	done
	echo "$body_armor_equipped" > "$SAVE_DIR/body_armor_equipped.sav"

	# Сохраняем навыки
	: > "$SAVE_DIR/skills.sav" # Очищаем файл
	for key in "${!skills[@]}"; do
		printf "%s %s\n" "$key" "${skills[$key]}" >> "$SAVE_DIR/skills.sav"
	done

	echo "Игра успешно сохранена."
	read -r -p "Нажмите Enter, чтобы продолжить..."
}

# Загрузка состояния игры из файла
load_game() {
	local IFS=$'\n' # Устанавливаем разделитель для read -a
	if [[ -f "$SAVE_DIR/player_name.sav" && \
          -f "$SAVE_DIR/location.sav" && \
          -f "$SAVE_DIR/cash.sav" && \
          -f "$SAVE_DIR/health.sav" && \
          -f "$SAVE_DIR/guns.sav" && \
          -f "$SAVE_DIR/items.sav" && \
          -f "$SAVE_DIR/body_armor_equipped.sav" && \
          -f "$SAVE_DIR/skills.sav" && \
          -f "$SAVE_DIR/drugs.sav" ]]; then

		read -r player_name < "$SAVE_DIR/player_name.sav"
		read -r location < "$SAVE_DIR/location.sav"
		read -r cash < "$SAVE_DIR/cash.sav"
		read -r health < "$SAVE_DIR/health.sav"

        # Читаем массивы правильно
        guns=() # Очищаем массив перед загрузкой
        while IFS= read -r gun_line || [[ -n "$gun_line" ]]; do
            [[ -n "$gun_line" ]] && guns+=("$gun_line")
        done < "$SAVE_DIR/guns.sav"

        items=() # Очищаем массив
        while IFS= read -r item_line || [[ -n "$item_line" ]]; do
             [[ -n "$item_line" ]] && items+=("$item_line")
        done < "$SAVE_DIR/items.sav"

		read -r body_armor_equipped < "$SAVE_DIR/body_armor_equipped.sav"

        # Загружаем ассоциативные массивы
		declare -A drugs # Переобъявляем, чтобы очистить
		while IFS=' ' read -r key value || [[ -n "$key" ]]; do # Читаем ключ и значение
            # Проверка, что ключ не пустой (избегаем ошибок с пустыми строками)
			if [[ -n "$key" ]]; then
				drugs["$key"]="$value"
			fi
		done < "$SAVE_DIR/drugs.sav"

		declare -A skills # Переобъявляем
		while IFS=' ' read -r key value || [[ -n "$key" ]]; do
            if [[ -n "$key" ]]; then
                skills["$key"]="$value"
            fi
		done < "$SAVE_DIR/skills.sav"

		echo "Игра успешно загружена."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		IFS=$' \t\n' # Восстанавливаем IFS
		return 0 # Успешная загрузка
	else
		echo "Сохраненная игра не найдена."
		read -r -p "Нажмите Enter, чтобы продолжить..."
		IFS=$' \t\n' # Восстанавливаем IFS
		return 1 # Ошибка загрузки
	fi
}


# --- 4. Инициализация игры и цикл ---

# Функция для инициализации игровых переменных
Game_variables() {
	clear_screen
	read -r -p "Введите имя вашего игрока: " player_name
	play_sfx_mpg "new_game" # Звук новой игры
	location="Los Santos" # Стартовая локация (внутреннее имя)
	cash=500
	health=100
	guns=()
	items=()
	declare -A drugs # Инициализируем пустой массив
    # Можно добавить стартовые наркотики, если нужно
	# drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )
	# Инициализация навыков
	declare -A skills
	skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
	clear_screen
}

# Функция для удаления файлов сохранения
remove_save_files() {
	rm -f "$SAVE_DIR/player_name.sav" \
          "$SAVE_DIR/location.sav" \
          "$SAVE_DIR/cash.sav" \
          "$SAVE_DIR/health.sav" \
          "$SAVE_DIR/guns.sav" \
          "$SAVE_DIR/items.sav" \
          "$SAVE_DIR/drugs.sav" \
          "$SAVE_DIR/body_armor_equipped.sav" \
          "$SAVE_DIR/skills.sav" # Удаляем файл сохранения навыков

	# Проверяем, существует ли директория (не обязательно после rm -f)
	# if [[ ! -d "$SAVE_DIR" ]]; then
	# 	echo "Сохраненная игра не найдена."
	# else
	#	echo "Старое сохранение удалено!"
	# fi
    # Просто сообщаем об удалении, если команда rm была вызвана
    echo "Старое сохранение удалено (если оно существовало)."

}

# Начальное меню игры
while true; do
	clear_screen
	echo "Добро пожаловать в Bash Theft Auto" # Можно перевести название
	echo "Выберите опцию:"
	echo "1. Новая игра"
	echo "2. Загрузить игру"
	echo "3. Выйти из игры"
	read -r -p "Введите ваш выбор: " initial_choice
	[[ ! "$initial_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод. Пожалуйста, введите номер."
		sleep 2
		continue
	}
	case "$initial_choice" in
		1) remove_save_files; Game_variables; break;; # Начать новую игру
		2) if load_game; then break; else continue; fi;; # Загрузить и выйти из цикла меню, если успешно
		3) exit 0;; # Выход из игры
		*) echo "Неверный выбор."; sleep 2;;
	esac
done

# Основной игровой цикл
while true; do
clear_screen
echo "Выберите действие:"
echo "1. Путешествовать в другой штат"
echo "2. Купить оружие"
echo "3. Показать инвентарь"
echo "4. Работать (заработать деньги)"
echo "5. Преступная деятельность"
echo "6. Купить наркотики"
echo "7. Продать наркотики"
echo "8. Нанять проститутку"
echo "9. Посетить больницу"
echo "10. Выйти из игры"
echo "11. Сохранить игру"
echo "12. Загрузить игру" # Опция загрузки в процессе игры
echo "13. Включить музыку"
echo "14. О программе"
read -r -p "Введите ваш выбор: " choice
[[ ! "$choice" =~ ^[0-9]+$ ]] && {
	echo "Неверный ввод. Пожалуйста, введите номер."
	sleep 2
	continue
}
case "$choice" in
	1) clear
	echo "Выберите штат для путешествия:"
	echo "1. Лос-Сантос (50$)"
	echo "2. Сан-Фиерро (75$)"
	echo "3. Лас-Вентурас (100$)"
	echo "4. Вайс-Сити (150$)"
	echo "5. Либерти-Сити (200$)"
	echo "6. Назад в главное меню"
	read -r -p "Введите ваш выбор: " city_choice
	[[ ! "$city_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод. Пожалуйста, введите номер."
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
		*) echo "Неверный выбор."; sleep 2;;
	esac;;
	2) buy_guns;;
	3) show_inventory;;
	4) clear
	echo "Выберите работу:"
	echo "1. Таксист"
	echo "2. Курьер"
	echo "3. Механик"
	echo "4. Охранник"
	echo "5. Уличный артист"
	echo "6. Назад в главное меню"
	read -r -p "Введите ваш выбор: " job_choice
	[[ ! "$job_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод. Пожалуйста, введите номер."
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
		*) echo "Неверный выбор."; sleep 2;;
	esac;;
	5) clear
	echo "Выберите преступную деятельность:"
	echo "1. Ограбление (крупное)"
	echo "2. Война банд"
	echo "3. Угон автомобиля"
	echo "4. Ограбление магазина"
    echo "5. Уличные гонки"
	echo "6. Назад в главное меню"
	read -r -p "Введите ваш выбор: " criminal_choice
	[[ ! "$criminal_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод. Пожалуйста, введите номер."
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
		*) echo "Неверный выбор."; sleep 2;;
	esac;;
	6) buy_drugs;;
	7) sell_drugs;;
	8) hire_hooker;;
	9) visit_hospital;;
	10) exit 0;; # Выход из игры
	11) save_game;;
	12) load_game;; # Загрузка во время игры
	13) play_music;;
	14) about_music_sfx;;
	*) echo "Неверный выбор."; sleep 2;;
	esac
done

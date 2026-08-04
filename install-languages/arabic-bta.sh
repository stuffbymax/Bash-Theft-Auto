# Bash-Theft-Auto music and sfx © 2024 by stuffbymax - Martin Petik مرخص بموجب CC BY 4.0
# https://creativecommons.org/licenses/by/4.0/
# الإصدار 2.0.5 (إصلاحات صدى الطرفية)
#!/bin/bash

# --- الإعداد الأولي ---
# تعيين BASEDIR إلى الدليل الذي يوجد به السكربت
# استخدام توسيع المعلمات للتوافق المحتمل الأفضل من realpath
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# الخروج عند الخطأ لمنع السلوك غير المتوقع
# set -e # قم بإلغاء التعليق للتحقق الصارم من الأخطاء إذا رغبت في ذلك، ولكنه قد يخرج بسهولة شديدة

# --- وظيفة التنظيف والفخ ---
cleanup_and_exit() {
    echo -e "\nجاري التنظيف والخروج..."
    # إيقاف الموسيقى إذا كانت تعمل
    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
        echo "إيقاف الموسيقى (PID: $music_pid)..."
        kill "$music_pid" &>/dev/null
        wait "$music_pid" 2>/dev/null
        music_pid=""
    fi
    # استعادة صدى الطرفية
    stty echo
    echo "اكتمل التنظيف. وداعًا."
    exit 0
}
# اعتراض إشارات الخروج الشائعة لتشغيل وظيفة التنظيف
trap cleanup_and_exit SIGINT SIGTERM SIGHUP

# --- 0. المتغيرات العامة ---
player_name=""
location="Los Santos" # الموقع الافتراضي للبدء
cash=0
health=100 # الصحة الافتراضية للبدء
declare -a guns=()
declare -a items=()
declare -A drugs=()
declare -A skills=()
body_armor_equipped=false
SAVE_DIR="saves" # نسبة إلى BASEDIR
declare -A gun_attributes=()
music_pid="" # PID لمشغل الموسيقى في الخلفية

# تهيئة سمات الأسلحة (تأكد من ملء المصفوفة)
# ملاحظة: أسماء الأسلحة الداخلية باللغة الإنجليزية للمفاتيح
gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

# تهيئة المهارات/المخدرات الافتراضية (تستخدم في load_game و new_game)
# ملاحظة: المفاتيح الداخلية باللغة الإنجليزية
declare -A default_skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
declare -A default_drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )


# --- التحقق من الاعتماديات ---
mpg123_available=true
if ! command -v mpg123 &> /dev/null; then
    echo "###########################################################"
    echo "# تحذير: الأمر 'mpg123' غير موجود.                        #" # Warning: 'mpg123' command not found.
    echo "# المؤثرات الصوتية والموسيقى تتطلب mpg123.                #" # Sound effects and music require mpg123.
    echo "# يرجى تثبيته للحصول على التجربة الكاملة.                  #" # Please install it for the full experience.
    echo "#---------------------------------------------------------#"
    echo "# على Debian/Ubuntu: sudo apt update && sudo apt install mpg123 #"
    echo "# على Fedora:        sudo dnf install mpg123               #"
    echo "# على Arch Linux:    sudo pacman -S mpg123                 #"
    echo "# على macOS (Homebrew): brew install mpg123                #"
    echo "###########################################################"
    read -r -p "اضغط Enter للمتابعة بدون صوت..." # Press Enter to continue without sound...
    mpg123_available=false
fi

# --- إعداد المؤثرات الصوتية ---
sfx_dir="sfx"  # دليل المؤثرات الصوتية نسبة إلى BASEDIR

# وظيفة لتشغيل المؤثرات الصوتية (تعالج mpg123 المفقود)
play_sfx_mpg() {
    if ! $mpg123_available; then
        return 1 # الصوت معطل
    fi
    local sound_name="$1"
    local sound_file="$BASEDIR/$sfx_dir/${sound_name}.mp3"
    if [[ -f "$sound_file" ]]; then
        if command -v mpg123 &> /dev/null; then
           # تشغيل في الخلفية، منفصل، تجاهل stdout/stderr إلا في حالة التصحيح
           mpg123 -q "$sound_file" &>/dev/null &
            return 0  # يشير إلى النجاح
        fi
    else
        # تجاهل ملفات SFX المفقودة بصمت أو تسجيلها إذا كان التصحيح قيد التشغيل
        # >&2 echo "تصحيح: ملف الصوت غير موجود: '$sound_file'" # Debug: Sound file not found: '$sound_file'
        return 1
    fi
    return 1 # يشير إلى الفشل (على سبيل المثال، فشل التحقق من mpg123 بالداخل)
}

# --- 1. تحميل الإضافات ---
plugin_dir="plugins" # نسبة إلى BASEDIR

if [[ -d "$BASEDIR/$plugin_dir" ]]; then
	# استخدم find ضمن سياق BASEDIR
	while IFS= read -r -d $'\0' plugin_script; do
		# استدعاء الإضافة باستخدام مسارها الكامل
		if [[ -f "$plugin_script" ]]; then
            # >&2 echo "تحميل الإضافة: $plugin_script" # Debug message: Loading plugin: $plugin_script
            source "$plugin_script"
        fi
	done < <(find "$BASEDIR/$plugin_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
else
	# ليس بالضرورة خطأ، مجرد معلومات
	echo "معلومة: دليل الإضافات '$BASEDIR/$plugin_dir' غير موجود. تخطي تحميل الإضافات." # Info: Plugin directory '$BASEDIR/$plugin_dir' not found. Skipping plugin load.
fi

# --- 3. الوظائف ---

# مسح الشاشة وعرض رأس معلومات اللعبة
# ملاحظة: قد تبدو المحاذاة غريبة في الطرفيات التي لا تدعم RTL بشكل جيد
clear_screen() {
    clear
    printf "\e[93m=========================================\e[0m\n"
    printf "\e[1;43m|        Bash Theft Auto                |\e[0m\n"
    printf "\e[93m=========================================\e[0m\n"
    # حاول ترتيب العناصر بصريًا لـ RTL، لكن احتفظ بالمتغيرات الإنجليزية
    printf " اللاعب: %-15s | الموقع: %s\n" "$player_name" "$location" # Player: %-15s Location: %s
    printf " المال: \$%-16d | الصحة: %d%%\n" "$cash" "$health" # Cash: \$%-16d Health: %d%%
    # عرض حالة الدرع الواقي
    if $body_armor_equipped; then
        printf " الدرع: \e[1;32mمجهز\e[0m\n" # Armor: Equipped
    else
        printf " الدرع: \e[1;31mلا يوجد\e[0m\n" # Armor: None
    fi
    printf "\e[1;34m=========================================\e[0m\n"
}

# --- حول ---
about_music_sfx() {
	clear_screen
	echo "-----------------------------------------"
	echo "|    حول الموسيقى والمؤثرات الصوتية     |" # About the Music and Sound Effects
	echo "-----------------------------------------"
	echo ""
	echo "الموسيقى والمؤثرات الصوتية © 2024 بواسطة stuffbymax - Martin Petik" # Music and SFX © 2024 by stuffbymax - Martin Petik
	echo "مرخص بموجب CC BY 4.0:" # Licensed under CC BY 4.0:
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "لك الحرية في مشاركة وتعديل هذه المواد" # You are free to share and adapt this material
	echo "لأي غرض، حتى تجاريًا، بشرط" # for any purpose, even commercially, under the
	echo "أن تنسب العمل لصاحبه بشكل مناسب." # condition that you give appropriate credit.
	echo ""
	echo "مثال على النسبة:" # Attribution example:
	echo "'Music/SFX © 2024 stuffbymax - Martin Petik, CC BY 4.0'" # 'Music/SFX © 2024 stuffbymax - Martin Petik, CC BY 4.0'
	echo ""
	echo "مزيد من المعلومات: https://stuffbymax.me/" # More info: https://stuffbymax.me/
	echo ""
	echo "-----------------------------------------"
	echo "|          رخصة الكود                    |" # Code License
	echo "-----------------------------------------"
	echo ""
	echo "كود اللعبة © 2024 stuffbymax" # Game Code © 2024 stuffbymax
	echo "مرخص بموجب رخصة MIT." # Licensed under the MIT License.
	echo "يسمح بإعادة الاستخدام مع ذكر المصدر." # Allows reuse with attribution.
	echo ""
	echo "الرخصة الكاملة:" # Full License:
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE" # تأكد من أن هذا الرابط صحيح
	echo ""
	echo "شكرا للعب!" # Thank you for playing!
    echo "-----------------------------------------"
	read -r -p "اضغط Enter للعودة..." # Press Enter to return...
}

# وظيفة للتحقق مما إذا كان اللاعب على قيد الحياة ومعالجة الموت
check_health() {
	if (( health <= 0 )); then
        health=0 # منع عرض الصحة السالبة
		clear_screen
		echo -e "\n      \e[1;31m هــُــزِمــت \e[0m\n" # W A S T E D (Arabic style 'Wasted')
		play_sfx_mpg "wasted"
		echo "لقد انهرت من إصاباتك..." # You collapsed from your injuries...
		sleep 1
		echo "استيقظت لاحقًا..." # You wake up later...
		read -r -p "اضغط Enter للذهاب إلى المستشفى..." # Press Enter to go to the hospital...
		hospitalize_player # يعالج عواقب الموت
        return 1 # يشير إلى أن اللاعب تم نقله إلى المستشفى (مات)
	fi
    return 0 # يشير إلى أن اللاعب بخير
}

# وظيفة للسفر إلى موقع جديد
travel_to() {
	local travel_cost="$1"
	local new_location="$2"
    local current_location="$location" # تخزين الموقع الحالي للرسالة

    # منع السفر إلى نفس الموقع
    if [[ "$new_location" == "$current_location" ]]; then
        echo "أنت بالفعل في $new_location." # You are already in $new_location.
        read -r -p "اضغط Enter..." # Press Enter...
        return
    fi

	if (( cash >= travel_cost )); then
		printf "السفر من %s إلى %s (\$%d)...\n" "$current_location" "$new_location" "$travel_cost" # Traveling from %s to %s (\$%d)...
		play_sfx_mpg "air"

		# --- رسوم متحركة للسفر الجوي (استدعاء إضافة اختياري) ---
        if command -v air_travel_animation &> /dev/null; then
		    air_travel_animation "$current_location" "$new_location" # تمرير المواقع ربما؟
        else
            # رسوم متحركة نصية بسيطة إذا كانت الإضافة مفقودة
            echo -n "["
            for _ in {1..20}; do echo -n "="; sleep 0.05; done
            echo ">]"
        fi
		# --- نهاية الرسوم المتحركة ---

		cash=$((cash - travel_cost))
		location="$new_location"
		echo "لقد وصلت بأمان إلى $new_location." # You have arrived safely in $new_location.
        read -r -p "اضغط Enter..." # Press Enter...
	else
		echo "لا يوجد مال كافٍ (\$$travel_cost مطلوب) للسفر إلى $new_location." # Not enough cash (\$$travel_cost needed) to travel to $new_location.
		read -r -p "اضغط Enter..." # Press Enter...
	fi
}

# وظيفة لقائمة شراء الأسلحة
buy_guns() {
	local gun_choice=""
	clear_screen
	echo "--- Ammu-Nation ---"
	echo "أهلاً بك! ماذا يمكنني أن أقدم لك؟" # Welcome! What can I get for you?
	echo "-------------------"
	echo "1. مسدس       (\$100)" # 1. Pistol      ($100)
	echo "2. بندقية     (\$250)" # 2. Shotgun     ($250)
	echo "3. SMG         (\$500)" # 3. SMG         ($500)
	echo "4. بندقية آلية (\$750)" # 4. Rifle       ($750) -> بندقية آلية
	echo "5. بندقية قنص (\$1000)" # 5. Sniper      ($1000) -> بندقية قنص
	echo "-------------------"
	echo "6. مغادرة" # 6. Leave
    echo "-------------------"
    printf "أموالك: \$%d\n" "$cash" # Your Cash: $%d
	read -r -p "أدخل اختيارك: " gun_choice # Enter your choice:

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "إدخال غير صالح."; read -r -p "اضغط Enter..."; return # Invalid input. Press Enter...
	}

	case "$gun_choice" in
		1) buy_gun "Pistol" 100;; # تمرير الاسم الداخلي الإنجليزي
		2) buy_gun "Shotgun" 250;;
		3) buy_gun "SMG" 500;;
		4) buy_gun "Rifle" 750;;
		5) buy_gun "Sniper" 1000;;
		6) echo "عد في أي وقت!"; sleep 1; return;; # Come back anytime!
		*) echo "اختيار غير صالح."; read -r -p "اضغط Enter...";; # Invalid choice. Press Enter...
	esac
}

# وظيفة مساعدة لشراء الأسلحة تحديدًا
buy_gun() {
	local gun_name_internal="$1" # Expecting internal English name
	local gun_cost="$2"
    local owned=false
    local gun_name_display="" # Translated name for display

    # Map internal name to display name
    case "$gun_name_internal" in
        "Pistol") gun_name_display="مسدس";;
        "Shotgun") gun_name_display="بندقية";;
        "SMG") gun_name_display="SMG";;
        "Rifle") gun_name_display="بندقية آلية";;
        "Sniper") gun_name_display="بندقية قنص";;
        *) gun_name_display="$gun_name_internal" ;; # Fallback
    esac

    # التحقق مما إذا كان مملوكًا بالفعل (باستخدام الاسم الداخلي)
    for owned_gun in "${guns[@]}"; do
        if [[ "$owned_gun" == "$gun_name_internal" ]]; then
            owned=true
            break
        fi
    done
    if $owned; then
        echo "يبدو أن لديك $gun_name_display بالفعل يا صديقي." # Looks like you already got a $gun_name_display there, partner.
        read -r -p "اضغط Enter..." # Press Enter...
        return
    fi

    # التحقق من المال
	if (( cash >= gun_cost )); then
        play_sfx_mpg "cash_register"
		# --- رسوم متحركة للشراء (استدعاء إضافة اختياري) ---
        if command -v buy_animation &> /dev/null; then
            buy_animation "$gun_name_internal" # Use internal name if plugin expects it
        fi
        # --- نهاية الرسوم المتحركة ---

		cash=$((cash - gun_cost))
		guns+=("$gun_name_internal") # إضافة الاسم الداخلي (الإنجليزي) إلى مصفوفة الأسلحة
		echo "واحد $gun_name_display، قادم حالاً! سيكون ذلك \$ $gun_cost." # One $gun_name_display, coming right up! That'll be \$$gun_cost.
		read -r -p "اضغط Enter..." # Press Enter...
	else
		echo "آسف يا صديقي، لا يوجد مال كافٍ لـ $gun_name_display (\$ $gun_cost مطلوب)." # Sorry pal, not enough cash for the $gun_name_display (\$$gun_cost needed).
		read -r -p "اضغط Enter..." # Press Enter...
	fi
}

# وظيفة لعرض المخزون
show_inventory() {
	clear_screen
	echo "--- المخزون والإحصائيات ---" # Inventory & Stats
	printf " المال: \$%d\n" "$cash" # Cash: $%d
	printf " الصحة: %d%%\n" "$health" # Health: %d%%
    if $body_armor_equipped; then
        printf " الدرع: \e[1;32mمجهز\e[0m\n" # Armor: Equipped
    else
        printf " الدرع: \e[1;31mلا يوجد\e[0m\n" # Armor: None
    fi
	echo "--------------------------"
    echo " الأسلحة:" # Guns:
    if (( ${#guns[@]} > 0 )); then
        # عرض الأسماء المترجمة
        local translated_gun_name=""
        for gun in "${guns[@]}"; do # Iterate internal names
             case "$gun" in
                "Pistol") translated_gun_name="مسدس";;
                "Shotgun") translated_gun_name="بندقية";;
                "SMG") translated_gun_name="SMG";;
                "Rifle") translated_gun_name="بندقية آلية";;
                "Sniper") translated_gun_name="بندقية قنص";;
                *) translated_gun_name="$gun" ;; # Fallback
            esac
            printf "  - %s\n" "$translated_gun_name"
        done
    else
        echo "  (لا يوجد)" # (None)
    fi
    echo "--------------------------"
    echo " العناصر:" # Items:
     if (( ${#items[@]} > 0 )); then
        # تنفيذ استخدام العناصر هنا لاحقًا؟
        # الاحتفاظ بأسماء العناصر باللغة الإنجليزية حاليًا ما لم يحدد خلاف ذلك
         local translated_item_name=""
         for item in "${items[@]}"; do
             case "$item" in
                "Health Pack") translated_item_name="حزمة صحة";;
                # Add other item translations here if needed
                *) translated_item_name="$item" ;;
            esac
            printf "  - %s\n" "$translated_item_name"
         done
    else
        echo "  (لا يوجد)" # (None)
    fi
	echo "--------------------------"
	echo " المخدرات:" # Drugs:
	local drug_found=false
    for drug in "${!default_drugs[@]}"; do # تكرار المفاتيح الافتراضية للحفاظ على الترتيب (المفاتيح الإنجليزية)
        local amount=${drugs[$drug]:-0}
        if (( amount > 0 )); then
            # الاحتفاظ بأسماء المخدرات باللغة الإنجليزية للاتساق الداخلي
            printf "  - %-10s: %d وحدة\n" "$drug" "$amount" # units
            drug_found=true
        fi
    done
    if ! $drug_found; then echo "  (لا يوجد)"; fi # (None)
    echo "--------------------------"
	echo " المهارات:" # Skills:
    local translated_skill_name=""
    for skill in "${!default_skills[@]}"; do # تكرار المفاتيح الافتراضية (المفاتيح الإنجليزية)
         case "$skill" in
            "driving") translated_skill_name="قيادة";;
            "strength") translated_skill_name="قوة";;
            "charisma") translated_skill_name="كاريزما";;
            "stealth") translated_skill_name="تخفي";;
            "drug_dealer") translated_skill_name="تاجر مخدرات";;
            *) translated_skill_name="$skill" ;; # Fallback
        esac
        # قد تحتاج إلى تعديل العرض للمحاذاة في RTL
        printf "  - %-18s: %d\n" "$translated_skill_name" "${skills[$skill]:-0}"
    done
	echo "--------------------------"
	read -r -p "اضغط Enter للعودة..." # Press Enter to return...
}

# وظيفة للعمل (وظائف قانونية)
work_job() {
	local job_type_display="$1" # Expecting Arabic job type from menu
	local earnings=0 base_earnings=0 skill_bonus=0
	local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name="" # Internal English skill name
    local job_type_internal="" # Internal English job type name

	# تحديد نطاق الأجر الأساسي والمهارة ذات الصلة حسب الموقع
	case "$location" in
		"Los Santos")   min_earnings=20; max_earnings=60;;
		"San Fierro")   min_earnings=25; max_earnings=70;;
		"Las Venturas") min_earnings=30; max_earnings=90;;
		"Vice City")    min_earnings=15; max_earnings=50;;
		"Liberty City") min_earnings=35; max_earnings=100;;
		*)              min_earnings=10; max_earnings=40;;
	esac
    base_earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))

    # تحديد تأثير المهارة بناءً على نوع الوظيفة (ربط من العربية إلى الداخلية)
	case "$job_type_display" in
		"سائق تاكسي"|"توصيل")
            job_type_internal=$([[ "$job_type_display" == "سائق تاكسي" ]] && echo "taxi" || echo "delivery")
            relevant_skill_name="driving"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * (job_type_internal == "delivery" ? 4 : 3) )) # التوصيل يستخدم المهارة أكثر قليلاً
            [[ "$job_type_internal" == "delivery" ]] && base_earnings=$((base_earnings + 10))
			play_sfx_mpg "taxi" # الاحتفاظ باسم SFX متسقًا
			;;
		"ميكانيكي")
            job_type_internal="mechanic"
            relevant_skill_name="strength" # ربما القوة للرفع؟ أو إضافة مهارة محددة لاحقًا
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 1))
            base_earnings=$((base_earnings + 20))
			play_sfx_mpg "mechanic"
			;;
		"حارس أمن")
            job_type_internal="security"
            relevant_skill_name="strength"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 2))
            base_earnings=$((base_earnings + 30))
			play_sfx_mpg "security"
			;;
		"فنان شارع")
            job_type_internal="performer"
            relevant_skill_name="charisma"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 5))
            base_earnings=$((base_earnings - 10)) # أساس أقل موثوقية
            base_earnings=$(( base_earnings < 5 ? 5 : base_earnings )) # أساس أدنى 5
			play_sfx_mpg "street_performer"
			;;
		*) echo "خطأ داخلي: نوع وظيفة غير صالح '$job_type_display'"; return;; # Internal Error: Invalid Job Type '$job_type_display'
	esac

    earnings=$((base_earnings + skill_bonus))
    (( earnings < 0 )) && earnings=0 # التأكد من أن الأرباح ليست سالبة

    # --- رسوم متحركة للعمل (استدعاء إضافة اختياري) ---
    if command -v working_animation &> /dev/null; then
	    working_animation "$job_type_internal" # Use internal name if plugin expects it
    else
        echo "أعمل كـ $job_type_display..." # Working as a $job_type_display...
        sleep 2
    fi
    # --- نهاية الرسوم المتحركة ---

	# --- النتيجة ---
	cash=$((cash + earnings))
	clear_screen
	printf "أنهيت نوبتك كـ %s في %s.\n" "$job_type_display" "$location" # Finished your shift as a %s in %s.
    printf "لقد ربحت \$%d (الأساس: \$%d، مكافأة المهارة: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus" # You earned $%d (Base: $%d, Skill Bonus: $%d).
    printf "لديك الآن \$%d.\n" "$cash" # You now have $%d.

    # زيادة محتملة في المهارة
    if [[ -n "$relevant_skill_name" ]]; then # فقط إذا كانت المهارة ذات صلة
        local skill_increase_chance=20 # 20% فرصة أساسية
        if (( RANDOM % 100 < skill_increase_chance )); then
            skills[$relevant_skill_name]=$((relevant_skill_level + 1))
            local translated_skill_name=""
             case "$relevant_skill_name" in # ترجمة اسم المهارة للعرض
                "driving") translated_skill_name="قيادة";;
                "strength") translated_skill_name="قوة";;
                "charisma") translated_skill_name="كاريزما";;
                *) translated_skill_name="$relevant_skill_name" ;;
            esac
            printf "لقد زادت مهارتك في \e[1;32m%s\e[0m!\n" "$translated_skill_name" # Your %s skill increased!
        fi
    fi

	read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
}

# وظيفة لسباق الشوارع
street_race() {
    local driving_skill=${skills[driving]:-1}
	local base_win_chance=40
	local win_chance=$(( base_win_chance + driving_skill * 5 ))
    (( win_chance > 90 )) && win_chance=90 # تحديد الحد الأقصى لفرصة الفوز بنسبة 90%
    (( win_chance < 10 )) && win_chance=10 # الحد الأدنى لفرصة الفوز 10%

    clear_screen
    echo "--- سباق الشوارع ---" # Street Race
    echo "الانضمام إلى سباق شوارع غير قانوني في $location..." # Joining an illegal street race in $location...
    echo "مهارة القيادة: $driving_skill | فرصة الفوز: ${win_chance}%" # Driving Skill: $driving_skill | Win Chance: ${win_chance}%
    sleep 1

    # --- رسوم متحركة لسباق الشوارع (استدعاء إضافة اختياري) ---
    if command -v race_animation &> /dev/null; then
        race_animation
    elif command -v working_animation &> /dev/null; then
        working_animation "street_race" # الرجوع إلى الرسوم المتحركة العامة
    else
        echo "استعد..." ; sleep 1; echo "3... 2... 1... انطلق!"; sleep 1 # Get ready... ; 3... 2... 1... GO!
    fi
    # --- نهاية الرسوم المتحركة ---

    read -r -p "اضغط Enter لمعرفة نتائج السباق..." # Press Enter for the race results...

	local winnings=0 damage=0

	if (( RANDOM % 100 < win_chance )); then
        # --- الفوز ---
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10)) # الفوز 100-250 + مكافأة
		cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5)) # ضرر منخفض عند الفوز: 5-19%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "لقد امتص درعك الواقي \e[1;31m${armor_reduction}%%\e[0m من الضرر!" # Your body armor absorbed %d%% damage!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;32m*** لقد فزت بالسباق! ***\e[0m\n" # *** YOU WON THE RACE! ***
        printf "لقد جمعت \$%d كجائزة مالية.\n" "$winnings" # You collected $%d in prize money.
        printf "تلقيت ضررًا طفيفًا (-%d%% صحة).\n" "$damage" # Took minor damage (-%d%% health).
        play_sfx_mpg "win"
		# فرصة زيادة المهارة عند الفوز
		if (( RANDOM % 3 == 0 )); then # فرصة 33%
            skills[driving]=$((driving_skill + 1))
            printf "لقد زادت مهارتك في \e[1;32mالقيادة\e[0m!\n" # Your driving skill increased!
        fi
	else
        # --- الخسارة ---
        winnings=0 # لا أرباح عند الخسارة
		damage=$((RANDOM % 31 + 15)) # ضرر أعلى عند الخسارة: 15-45%
		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "لقد امتص درعك الواقي \e[1;31m${armor_reduction}%%\e[0m من الضرر في الحادث!" # Your body armor absorbed %d%% damage in the crash!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- لقد خسرت السباق! ---\e[0m\n" # --- YOU LOST THE RACE! ---
		printf "لقد تحطمت وتلقيت %d%% ضررًا.\n" "$damage" # You crashed and took %d%% damage.
		play_sfx_mpg "lose" # أو صوت تحطم؟ "car_crash"?
	fi

    # عرض الإحصائيات النهائية للحدث
    printf "الحالة الحالية -> المال: \$%d | الصحة: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%

    # التحقق من الصحة بعد عرض النتائج
    check_health # سيتولى هذا أمر المستشفى إذا كانت الصحة <= 0
    read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
}

# (وظيفة use_guns تبقى دون تغيير - محفوظة للاستخدام المستقبلي المحتمل)
use_guns() {
    # This function expects internal English names, translate output only
	if [[ " ${guns[*]} " == *" $1 "* ]]; then
        local translated_gun_name=""
         case "$1" in
            "Pistol") translated_gun_name="المسدس";; "Shotgun") translated_gun_name="البندقية";;
            "SMG") translated_gun_name="SMG";; "Rifle") translated_gun_name="البندقية الآلية";;
            "Sniper") translated_gun_name="بندقية القنص";; *) translated_gun_name="$1" ;;
        esac
		echo "لقد استخدمت $translated_gun_name الخاص بك لهذه المهمة." # You used your $1 for this job.
		play_sfx_mpg "gun_shot"
		read -r -p "اضغط Enter..." # Press Enter...
	else
        local translated_gun_name=""
         case "$1" in
            "Pistol") translated_gun_name="مسدس";; "Shotgun") translated_gun_name="بندقية";;
            "SMG") translated_gun_name="SMG";; "Rifle") translated_gun_name="بندقية آلية";;
            "Sniper") translated_gun_name="بندقية قنص";; *) translated_gun_name="$1" ;;
        esac
		echo "ليس لديك $translated_gun_name. فشلت المهمة." # You don't have a $1. Job failed.
		read -r -p "اضغط Enter..." # Press Enter...
	fi
}

# وظيفة مساعدة لمعالجة اختيار السلاح وتطبيق المكافأة للإجراءات الإجرامية
apply_gun_bonus() {
    local base_chance=$1
    local action_message="$2" # Expecting Arabic action description
    local current_chance=$base_chance
    local gun_bonus=0
    local chosen_gun_display="" # Arabic name entered by user
    local chosen_gun_internal="" # Internal English name for logic/attributes
    local gun_found=false
    local success_bonus=0 # متغير محلي لالتقاط المكافأة من eval

    if (( ${#guns[@]} == 0 )); then
        echo "ليس لديك أسلحة! سيكون هذا أصعب بكثير." # You have no guns! This will be significantly harder.
        gun_bonus=-15 # عقوبة كبيرة لكونك غير مسلح
    else
        # عرض الأسلحة المتاحة بالأسماء المترجمة
        echo -n "الأسلحة المتاحة: " # Available guns:
        local first_gun=true
        for gun_internal in "${guns[@]}"; do
            local translated_gun_name=""
            case "$gun_internal" in
                "Pistol") translated_gun_name="مسدس";; "Shotgun") translated_gun_name="بندقية";;
                "SMG") translated_gun_name="SMG";; "Rifle") translated_gun_name="بندقية آلية";;
                "Sniper") translated_gun_name="بندقية قنص";; *) translated_gun_name="$gun_internal" ;;
            esac
            if ! $first_gun; then echo -n "، "; fi
            echo -n "$translated_gun_name"
            first_gun=false
        done
        echo "" # سطر جديد

        read -r -p "استخدام سلاح لـ $action_message؟ (ن/ل): " use_gun # Use a gun for this $action_message? (y/n): -> ن/ل for نعم/لا

        if [[ "$use_gun" == "ن" || "$use_gun" == "N" || "$use_gun" == "n" ]]; then # Check for Arabic 'ن' or 'n'/'N'
            read -r -p "أي سلاح؟ (أدخل الاسم بالضبط): " chosen_gun_display # Which gun? (Enter exact name):

            # ربط الاسم العربي بالاسم الداخلي الإنجليزي
            case "$chosen_gun_display" in
                "مسدس") chosen_gun_internal="Pistol";; "بندقية") chosen_gun_internal="Shotgun";; # Assuming "بندقية" means Shotgun here based on menu
                "SMG") chosen_gun_internal="SMG";; "بندقية آلية") chosen_gun_internal="Rifle";;
                "بندقية قنص") chosen_gun_internal="Sniper";;
                *) chosen_gun_internal="" ;; # ليس اسمًا عربيًا معترفًا به
            esac

            # التحقق مما إذا كان اللاعب يمتلك السلاح (بالاسم الداخلي)
            gun_found=false
            if [[ -n "$chosen_gun_internal" ]]; then
                for gun in "${guns[@]}"; do
                    if [[ "$gun" == "$chosen_gun_internal" ]]; then
                        gun_found=true
                        break
                    fi
                done
            fi

            if $gun_found; then
                echo "تسحب $chosen_gun_display الخاص بك!" # You draw your $chosen_gun_display!
                play_sfx_mpg "gun_cock"

                # تطبيق مكافأة السلاح إذا تم تعريفها (باستخدام الاسم الداخلي)
                if [[ -v "gun_attributes[$chosen_gun_internal]" ]]; then
                    eval "${gun_attributes[$chosen_gun_internal]}" # تعيين 'success_bonus' محليًا
                    gun_bonus=${success_bonus:-0}
                    if (( gun_bonus > 0 )); then
                        echo "الـ $chosen_gun_display يمنح فرصة نجاح \e[1;32m+${gun_bonus}%%\e[0m." # The $chosen_gun_display gives a +%d%% success chance.
                        play_sfx_mpg "gun_shot"
                    else
                        echo "الـ $chosen_gun_display لا يوفر أي ميزة محددة هنا." # The $chosen_gun_display provides no specific advantage here.
                    fi
                else
                    echo "تحذير: لا توجد سمات مكافأة محددة لـ '$chosen_gun_display'." # Warning: No bonus attributes defined for '$chosen_gun_display'.
                    gun_bonus=0
                fi
            else
                echo "أنت لا تملك '$chosen_gun_display'! المتابعة بدون مكافأة السلاح." # You don't own '$chosen_gun_display'! Proceeding without a gun bonus.
                gun_bonus=0
            fi
        else
            echo "المتابعة بدون استخدام سلاح." # Proceeding without using a gun.
            gun_bonus=-5 # عقوبة صغيرة لاختيار عدم استخدام سلاح متاح؟ اختياري.
        fi
    fi

    current_chance=$((current_chance + gun_bonus))

    # تقييد فرصة النجاح (على سبيل المثال، 5% إلى 95%)
    (( current_chance < 5 )) && current_chance=5
    (( current_chance > 95 )) && current_chance=95

    echo "$current_chance" # إرجاع الفرصة النهائية المحسوبة
}


# وظيفة لزيارة المستشفى (القائمة)
visit_hospital() {
	local hospital_choice=""
	while true; do # تكرار حتى يغادر المستخدم
	    clear_screen
	    echo "--- مستشفى المقاطعة العام ---" # County General Hospital
        printf " صحتك: %d%% | المال: \$%d\n" "$health" "$cash" # Your Health: %d%% | Cash: $%d
        echo "-------------------------------"
	    echo " الخدمات:" # Services:
	    echo " 1. علاج أساسي (\$50)     - شفاء إلى 100%" # 1. Basic Treatment ($50)  - Heal to 100%
	    echo " 2. فحص متقدم (\$100)    - شفاء إلى 110% (حد أقصى مؤقت)" # 2. Advanced Scan ($100) - Heal to 110% (Temporary Max)
	    echo " 3. شراء حزمة صحة (\$30) - إضافة 'حزمة صحة' إلى العناصر" # 3. Buy Health Pack ($30) - Add 'Health Pack' to Items
	    echo " 4. شراء درع واقٍ (\$75)   - تجهيز الدرع (استخدام مرة واحدة)" # 4. Buy Body Armor ($75)  - Equip Armor (One time use)
        echo "-------------------------------"
	    echo " 5. مغادرة المستشفى" # 5. Leave Hospital
        echo "-------------------------------"
	    read -r -p "أدخل اختيارك: " hospital_choice # Enter your choice:

	    [[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		    echo "إدخال غير صالح."; sleep 1; continue # Invalid input.
	    }

	    case "$hospital_choice" in
		    1) buy_hospital_item 50 "basic_treatment";; # Use internal key
		    2) buy_hospital_item 100 "advanced_treatment";; # Use internal key
		    3) buy_hospital_item 30 "health_pack";; # Use internal key
		    4) buy_hospital_item 75 "body_armor";; # Use internal key
		    5) echo "مغادرة المستشفى..."; sleep 1; return;; # Leaving the hospital...
		    *) echo "اختيار غير صالح."; sleep 1;; # Invalid choice.
	    esac
        # بعد إجراء ما، عد لإظهار القائمة مرة أخرى ما لم يختاروا المغادرة
    done
}

# وظيفة مساعدة لشراء عناصر المستشفى
buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2" # Internal English type
    local item_display_name="" # Arabic display name

    # ربط النوع الداخلي باسم العرض
    case "$item_type" in
        "basic_treatment") item_display_name="العلاج الأساسي";;
        "advanced_treatment") item_display_name="الفحص المتقدم";;
        "health_pack") item_display_name="حزمة الصحة";;
        "body_armor") item_display_name="الدرع الواقي";;
        *) item_display_name=$item_type;;
    esac

	if (( cash >= item_cost )); then
        play_sfx_mpg "cash_register"
		cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment")
				health=100
				echo "تلقيت علاجًا أساسيًا. تم استعادة الصحة بالكامل إلى 100%." # Received basic treatment. Health fully restored to 100%.
				play_sfx_mpg "heal"
				;;
			"advanced_treatment")
				health=110
				echo "اكتمل الفحص المتقدم. تم تعزيز الصحة إلى 110%!" # Advanced scan complete. Health boosted to 110%!
                echo "(ملاحظة: يتم حساب المزيد من الشفاء/الضرر من أساس 100% ما لم تكن الصحة > 100)" # (Note: Further healing/damage calculated from 100% base unless health is > 100)
				play_sfx_mpg "heal_adv"
				;;
			"health_pack")
				items+=("Health Pack") # إضافة الاسم الداخلي إلى مصفوفة العناصر
				echo "لقد اشتريت $item_display_name. (استخدام العنصر لم يتم تنفيذه بعد)" # You bought a Health Pack. (Item usage not yet implemented)
				play_sfx_mpg "item_buy"
				;;
			"body_armor")
                if $body_armor_equipped; then
                    echo "لديك بالفعل درع واقٍ مجهز." # You already have Body Armor equipped.
                    cash=$((cash + item_cost)) # استرداد
                    play_sfx_mpg "error"
                else
				    body_armor_equipped=true
				    echo "تم شراء الدرع الواقي وتجهيزه." # Body Armor purchased and equipped.
				    play_sfx_mpg "item_equip"
                fi
				;;
            *) # لا ينبغي الوصول إليه
                echo "خطأ داخلي: نوع عنصر مستشفى غير معروف '$item_type'" # Internal Error: Unknown hospital item type '$item_type'
                cash=$((cash + item_cost)) # استرداد
                ;;
		esac
        read -r -p "اضغط Enter..." # Press Enter...
	else
		echo "لا يوجد مال كافٍ لـ $item_display_name (\$ $item_cost مطلوب)." # Not enough cash for $item_display_name (\$$item_cost needed).
		read -r -p "اضغط Enter..." # Press Enter...
	fi
}

# وظيفة لسرقة متجر
rob_store() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((15 + stealth_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- سرقة متجر ---" # Rob Store
    echo "استطلاع متجر صغير في $location..." # Scoping out a convenience store in $location...
    sleep 1

    # --- رسوم متحركة للسرقة (استدعاء إضافة اختياري) ---
    if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "تنفيذ الخطوة..."; sleep 1; fi # Making your move...
    # --- نهاية الرسوم المتحركة ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "سرقة متجر") # تمرير وصف الإجراء بالعربية

    echo "حساب الاحتمالات... فرصة النجاح النهائية: ${final_success_chance}%" # Calculating odds... Final success chance: ${final_success_chance}%
    read -r -p "اضغط Enter لمحاولة السرقة..." # Press Enter to attempt the robbery...

    if (( RANDOM % 100 < final_success_chance )); then
        # --- النجاح ---
        loot=$((RANDOM % 151 + 50 + stealth_skill * 10)) # الغنيمة: 50-200 + مكافأة
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # الضرر: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "امتص الدرع الواقي \e[1;31m${armor_reduction}%%\e[0m من الضرر أثناء الهروب!" # Body armor absorbed %d%% damage during the getaway!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mنجاح!\e[0m لقد أخفت الكاتب وأخذت \$%d.\n" "$loot" # Success! You intimidated the clerk and grabbed $%d.
        printf "تعرضت لبعض الضرب الخفيف (-%d%% صحة).\n" "$damage" # Got slightly roughed up (-%d%% health).
        play_sfx_mpg "cash_register"
        # فرصة زيادة المهارة
        if (( RANDOM % 3 == 0 )); then
            skills[stealth]=$((stealth_skill + 1))
            printf "لقد زادت مهارتك في \e[1;32mالتخفي\e[0m!\n" # Your stealth skill increased!
        fi
    else
        # --- الفشل ---
        loot=0
        fine=$((RANDOM % 101 + 50)) # الغرامة: 50-150
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # الضرر: 10-35%

         if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "حماك الدرع الواقي من \e[1;31m${armor_reduction}%%\e[0m من الضرر أثناء الاعتقال!" # Body armor protected you from %d%% damage during the arrest!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mفشل!\e[0m انطلق الإنذار الصامت، وصلت الشرطة بسرعة.\n" # Failed! The silent alarm tripped, cops arrived quickly.
        printf "تم تغريمك \$%d وتلقيت %d%% ضررًا.\n" "$fine" "$damage" # You were fined $%d and took %d%% damage.
        play_sfx_mpg "police_siren"
    fi

    printf "الحالة الحالية -> المال: \$%d | الصحة: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health # التحقق من حالة الصحة بعد الحدث
    read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
}

# وظيفة للمشاركة في عملية سطو
heist() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((10 + stealth_skill * 6)) # أصعب من سرقة المتجر
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- تخطيط لعملية سطو ---" # Plan Heist
    echo "التخطيط لمهمة عالية المخاطر في $location..." # Planning a high-stakes job in $location...
    sleep 1

    # --- رسوم متحركة للسطو (استدعاء إضافة اختياري) ---
    if command -v heist_animation &> /dev/null; then heist_animation; else echo "تنفيذ الخطة..."; sleep 1; fi # Executing the plan...
    # --- نهاية الرسوم المتحركة ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "سطو") # تمرير وصف الإجراء بالعربية

    echo "تقييم المخاطر الأمنية... فرصة النجاح النهائية: ${final_success_chance}%" # Assessing security risks... Final success chance: ${final_success_chance}%
    read -r -p "اضغط Enter لتنفيذ عملية السطو..." # Press Enter to execute the heist...

	if (( RANDOM % 100 < final_success_chance )); then
        # --- النجاح ---
		loot=$((RANDOM % 501 + 250 + stealth_skill * 25)) # الغنيمة: 250-750 + مكافأة
		cash=$((cash + loot))
		damage=$((RANDOM % 31 + 15)) # الضرر: 15-45%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "امتص الدرع الواقي \e[1;31m${armor_reduction}%%\e[0m من الضرر أثناء تبادل إطلاق النار!" # Body armor absorbed %d%% damage during the firefight!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** نجحت عملية السطو! ***\e[0m\n لقد حصلت على \$%d!\n" "$loot" # *** HEIST SUCCESSFUL! *** You scored $%d!
        printf "هربت بإصابات بالغة (-%d%% صحة).\n" "$damage" # Escaped with significant injuries (-%d%% health).
        play_sfx_mpg "win_big"
        # زيادة المهارة
        if (( RANDOM % 2 == 0 )); then
            skills[stealth]=$((stealth_skill + 2)) # زيادة كبيرة
            printf "لقد زادت مهارتك في \e[1;32mالتخفي\e[0m بشكل كبير!\n" # Your stealth skill increased significantly!
        fi
	else
        # --- الفشل ---
        loot=0
		fine=$((RANDOM % 201 + 100)) # الغرامة: 100-300
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 41 + 20)) # الضرر: 20-60%

        if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "أنقذ الدرع الواقي حياتك من \e[1;31m${armor_reduction}%%\e[0m من الضرر!" # Body armor saved your life from %d%% damage!
			body_armor_equipped=false
		fi
        health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- فشلت عملية السطو! ---\e[0m\n كان الأمن مشددًا جدًا، تم إحباط المهمة.\n" # --- HEIST FAILED! --- Security was too tight, aborted the job.
		printf "لقد خسرت \$%d وتلقيت %d%% ضررًا.\n" "$fine" "$damage" # You lost $%d and took %d%% damage.
		play_sfx_mpg "lose_big"
	fi

    printf "الحالة الحالية -> المال: \$%d | الصحة: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
}

# وظيفة لحروب العصابات
gang_war() {
	if (( ${#guns[@]} == 0 )); then
		echo "تحتاج إلى سلاح لبدء حرب عصابات! اشتر واحدًا أولاً." # You need a weapon to start a gang war! Buy one first.
		read -r -p "اضغط Enter..." ; return # Press Enter...
	fi

    local strength_skill=${skills[strength]:-1}
    local base_chance=$((20 + strength_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- حرب العصابات ---" # Gang War
    echo "التوجه إلى منطقة الخصم في $location..." # Rolling up on rival territory in $location...
    sleep 1

	# --- رسوم متحركة لحرب العصابات (استدعاء إضافة اختياري) ---
    if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "بدأت الرصاصات تتطاير!"; sleep 1; fi # Bullets start flying!
    # --- نهاية الرسوم المتحركة ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "حرب عصابات") # تمرير وصف الإجراء بالعربية

    echo "تقييم قوة الخصم... فرصة النجاح النهائية: ${final_success_chance}%" # Assessing rival strength... Final success chance: ${final_success_chance}%
	read -r -p "اضغط Enter لبدء القتال..." # Press Enter to start the fight...

	if (( RANDOM % 100 < final_success_chance )); then
        # --- الفوز ---
		loot=$((RANDOM % 201 + 100 + strength_skill * 15)) # الغنيمة 100-300 + مكافأة
		cash=$((cash + loot))
		damage=$((RANDOM % 41 + 20)) # الضرر: 20-60%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "تلقى الدرع الواقي \e[1;31m${armor_reduction}%%\e[0m من الضرر من الرصاص!" # Body armor took %d%% damage from bullets!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** تم الفوز في حرب العصابات! ***\e[0m\n لقد استوليت على المنطقة وحصلت على \$%d كغنيمة.\n" "$loot" # *** GANG WAR WON! *** You claimed the turf and $%d in spoils.
        printf "تعرضت لأضرار جسيمة (-%d%% صحة).\n" "$damage" # Suffered heavy damage (-%d%% health).
		play_sfx_mpg "win"
        # زيادة المهارة
        if (( RANDOM % 2 == 0 )); then
            skills[strength]=$((strength_skill + 1))
            printf "لقد زادت مهارتك في \e[1;32mالقوة\e[0m!\n" # Your strength skill increased!
        fi
	else
        # --- الخسارة ---
        loot=0
		fine=$((RANDOM % 151 + 75)) # الغرامة: 75-225
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
		damage=$((RANDOM % 51 + 25)) # الضرر: 25-75%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "منع الدرع الواقي \e[1;31m${armor_reduction}%%\e[0m من الضرر القاتل!" # Body armor prevented %d%% fatal damage!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- خسرت حرب العصابات! ---\e[0m\n لقد تم اجتياحك وبالكاد هربت.\n" # --- GANG WAR LOST! --- You were overrun and barely escaped.
		printf "لقد خسرت \$%d وتلقيت %d%% ضررًا.\n" "$fine" "$damage" # You lost $%d and took %d%% damage.
		play_sfx_mpg "lose"
	fi

    printf "الحالة الحالية -> المال: \$%d | الصحة: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
}

# وظيفة لسرقة السيارات
carjack() {
    local driving_skill=${skills[driving]:-1}
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$(( 20 + driving_skill * 2 + stealth_skill * 3 ))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- سرقة سيارة ---" # Carjack
    echo "البحث عن مركبة 'لاستعارتها' في $location..." # Looking for a vehicle to 'borrow' in $location...
    sleep 1

    # --- رسوم متحركة لسرقة السيارة (استدعاء إضافة اختياري) ---
    if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "تحديد الهدف..."; sleep 1; fi # Spotting a target...
    # --- نهاية الرسوم المتحركة ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "سرقة سيارة") # تمرير وصف الإجراء بالعربية

    echo "اختيار الهدف... فرصة النجاح النهائية: ${final_success_chance}%" # Choosing a target... Final success chance: ${final_success_chance}%
    read -r -p "اضغط Enter لتنفيذ حركتك..." # Press Enter to make your move...

    if (( RANDOM % 100 < final_success_chance )); then
        # --- النجاح ---
        loot=$((RANDOM % 101 + 50 + driving_skill * 5)) # قيمة السيارة: 50 - 150 + مكافأة
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # الضرر: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "امتص الدرع الواقي \e[1;31m${armor_reduction}%%\e[0m من الضرر أثناء الهروب!" # Body armor absorbed %d%% damage during the getaway!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mنجاح!\e[0m لقد سرقت السيارة وبعتها مقابل \$%d.\n" "$loot" # Success! You boosted the car and fenced it for $%d.
        printf "تعرضت لبعض الصدمات الخفيفة (-%d%% صحة).\n" "$damage" # Got slightly banged up (-%d%% health).
        play_sfx_mpg "car_start"
        # فرص زيادة المهارات
        if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); printf "لقد زادت مهارتك في \e[1;32mالقيادة\e[0m!\n"; fi # Your driving skill increased!
        if (( RANDOM % 4 == 0 )); then skills[stealth]=$((stealth_skill+1)); printf "لقد زادت مهارتك في \e[1;32mالتخفي\e[0m!\n"; fi # Your stealth skill increased!
    else
        # --- الفشل ---
        loot=0
        fine=$((RANDOM % 76 + 25)) # الغرامة: 25-100
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # الضرر: 10-35%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "تلقى الدرع الواقي \e[1;31m${armor_reduction}%%\e[0m من الضرر عندما قاوم المالك!" # Body armor took %d%% damage when the owner fought back!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mفشل!\e[0m انطلق الإنذار / قاوم المالك / الشرطة قريبة.\n" # Failed! Alarm blared / Owner resisted / Cops nearby.
        printf "تم تغريمك \$%d وتلقيت %d%% ضررًا.\n" "$fine" "$damage" # You were fined $%d and took %d%% damage.
        play_sfx_mpg "police_siren"
    fi

    printf "الحالة الحالية -> المال: \$%d | الصحة: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
    read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
}

# وظيفة لمعالجة عواقب موت اللاعب (تستدعى بواسطة check_health)
hospitalize_player() {
	local hospital_bill=200
    echo "لقد قام المستشفى بترقيعك." # The hospital patched you up.
    sleep 1
    echo "لسوء الحظ، الرعاية الطبية ليست مجانية. الفاتورة: \$${hospital_bill}." # Unfortunately, medical care isn't free. Bill: $${hospital_bill}.

    if (( cash < hospital_bill )); then
        echo "لم تتمكن من تحمل الفاتورة كاملة (\$${hospital_bill}). أخذوا كل أموالك (\$$cash)." # You couldn't afford the full bill ($${hospital_bill}). They took all your cash ($$cash).
        hospital_bill=$cash
    else
        echo "لقد دفعت فاتورة \$${hospital_bill}." # You paid the $${hospital_bill} bill.
    fi

	cash=$((cash - hospital_bill))
    health=50 # إعادة تعيين الصحة إلى 50% بعد "الموت"
	body_armor_equipped=false # فقدان الدرع عند "الموت"
    play_sfx_mpg "cash_register" # صوت دفع الفاتورة

	printf "تغادر المستشفى بـ \$%d نقداً وصحة %d%%.\n" "$cash" "$health" # You leave the hospital with $%d cash and %d%% health.
	# الموقع لا يتغير عند الموت في هذه النسخة
    # يتم الاحتفاظ بعناصر المخزون (يمكن تغيير هذا لزيادة الصعوبة)
	read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
}

# وظيفة لاستئجار عاهرة (ملاحظة: محتوى حساس)
hire_hooker() {
    local charisma_skill=${skills[charisma]:-1}
    local base_min_cost=40 base_max_cost=100
    local cost_reduction=$((charisma_skill * 3))
    local min_cost=$((base_min_cost - cost_reduction))
    local max_cost=$((base_max_cost - cost_reduction))
    (( min_cost < 15 )) && min_cost=15
    (( max_cost <= min_cost )) && max_cost=$((min_cost + 20))

	local hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	local health_gain=$(( RANDOM % 21 + 15 )) # اكتساب صحة 15-35%
    # مراعاة الحد الأقصى للصحة (حاليًا 100 أو 110 إذا تم استخدام علاج متقدم)
    local max_health=100
    (( health > 100 )) && max_health=110 # تعديل الحد إذا كان لدى اللاعب دفعة مؤقتة

    clear_screen
    echo "--- البحث عن رفقة ---" # Seeking Company
	echo "البحث عن بعض 'تخفيف التوتر' في $location..." # Looking for some 'stress relief' in $location...
    sleep 1
    echo "تقترب من شخص واعد... يطلب منك \$ $hooker_cost." # You approach someone promising... They quote you $hooker_cost.

	if (( cash >= hooker_cost )); then
        read -r -p "قبول العرض؟ (ن/ل): " accept # Accept the offer? (y/n): -> ن/ل
        if [[ "$accept" == "ن" || "$accept" == "N" || "$accept" == "n" ]]; then # Check for Arabic 'ن' or 'n'/'N'
            play_sfx_mpg "cash_register"
	        cash=$(( cash - hooker_cost ))
	        local previous_health=$health
            health=$(( health + health_gain ))
	        (( health > max_health )) && health=$max_health # تطبيق الحد
            local actual_gain=$((health - previous_health))

            clear_screen
            echo "--- اكتملت الصفقة ---" # Transaction Complete
	        printf "لقد دفعت \$%d.\n" "$hooker_cost" # You paid $%d.
            if (( actual_gain > 0 )); then
                 printf "تشعر بالانتعاش، لقد اكتسبت \e[1;32m%d%%\e[0m صحة.\n" "$actual_gain" # Feeling refreshed, you gained %d%% health.
            else
                 echo "كنت بالفعل في أقصى صحة." # You were already at maximum health.
            fi
            printf "الحالة الحالية -> المال: \$%d | الصحة: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
	        play_sfx_mpg "hooker" # Sensitive SFX name
            # فرصة زيادة المهارة
            if (( RANDOM % 5 == 0 )); then
                skills[charisma]=$((charisma_skill+1))
                printf "لقد زادت مهارتك في \e[1;32mالكاريزما\e[0m!\n" # Your charisma skill increased!
            fi
        else
            echo "قررت عدم الموافقة وذهبت بعيدًا." # You decided against it and walked away.
        fi
    else
	    echo "تتحقق من محفظتك... لا يوجد مال كافٍ (\$ $hooker_cost مطلوب)." # You check your wallet... not enough cash ($hooker_cost needed).
	fi
    read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
}


# وظيفة مركزية لصفقات المخدرات
drug_transaction() {
	local action="$1" base_price="$3" drug_amount="$4"
    local drug_name="$2" # الاحتفاظ باسم المخدرات (داخلي، إنجليزي) منفصلاً للوضوح
    local cost=0 income=0 final_price=0
	local drug_dealer_skill=${skills[drug_dealer]:-1}

    # التحقق من أن المبلغ عدد صحيح موجب
    if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then
        echo "مبلغ غير صالح '$drug_amount'. يرجى إدخال رقم أكبر من 0." # Invalid amount '$drug_amount'. Please enter a number greater than 0.
        return 1
    fi

    # --- التسعير الديناميكي ---
    local price_fluctuation=$(( RANDOM % 21 - 10 )) # +/- 10%
    local location_modifier=0
    case "$location" in # مثال على المعدلات
        "Liberty City") location_modifier=15;; "Las Venturas") location_modifier=10;;
        "Vice City")    location_modifier=-15;; *) location_modifier=0;;
    esac
    local current_market_price=$(( base_price + (base_price * (price_fluctuation + location_modifier) / 100) ))
    (( current_market_price < 1 )) && current_market_price=1 # الحد الأدنى للسعر $1

    # --- إجراء الصفقة ---
	if [[ "$action" == "buy" ]]; then
        final_price=$current_market_price
		cost=$((final_price * drug_amount))

		if (( cash >= cost )); then
            if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "buy"; fi
			cash=$((cash - cost))
            drugs["$drug_name"]=$(( ${drugs[$drug_name]:-0} + drug_amount )) # استخدام اسم المخدرات الداخلي كمفتاح
			printf "تم شراء \e[1;33m%d\e[0m وحدة من \e[1;33m%s\e[0m مقابل \e[1;31m\$%d\e[0m (\$%d/وحدة).\n" \
                   "$drug_amount" "$drug_name" "$cost" "$final_price" # Bought %d units of %s for $%d ($%d/unit). (Kept internal drug name)
			play_sfx_mpg "cash_register" ; return 0
		else
			printf "لا يوجد مال كافٍ. تحتاج إلى \$%d، لديك \$%d.\n" "$cost" "$cash" ; return 1 # Not enough cash. Need $%d, you have $%d.
		fi

	elif [[ "$action" == "sell" ]]; then
        local current_inventory=${drugs[$drug_name]:-0} # استخدام اسم المخدرات الداخلي كمفتاح
		if (( current_inventory >= drug_amount )); then
            local price_bonus_percent=$((drug_dealer_skill * 2))
            final_price=$(( current_market_price + (current_market_price * price_bonus_percent / 100) ))
            (( final_price < 1 )) && final_price=1 # التأكد من أن سعر البيع لا ينخفض إلى أقل من 1 دولار بسبب المعدلات السلبية
			income=$((final_price * drug_amount))

            if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "sell"; fi
			cash=$((cash + income))
			drugs["$drug_name"]=$((current_inventory - drug_amount)) # استخدام اسم المخدرات الداخلي كمفتاح

			printf "تم بيع \e[1;33m%d\e[0m وحدة من \e[1;33m%s\e[0m مقابل \e[1;32m\$%d\e[0m (\$%d/وحدة، مهارة +%d%%).\n" \
                   "$drug_amount" "$drug_name" "$income" "$final_price" "$price_bonus_percent" # Sold %d units of %s for $%d ($%d/unit, skill +%d%%). (Kept internal drug name)
			play_sfx_mpg "cash_register"
            # فرصة زيادة المهارة
            if (( RANDOM % 2 == 0 )); then
			    skills[drug_dealer]=$((drug_dealer_skill + 1))
			    printf "لقد زادت مهارتك في \e[1;32mتجارة المخدرات\e[0m!\n" # Your drug dealing skill increased!
            fi ; return 0
		else
			printf "لا يوجد ما يكفي من %s للبيع. لديك %d وحدة، حاولت بيع %d.\n" \
                   "$drug_name" "$current_inventory" "$drug_amount" ; return 1 # Not enough %s to sell. You have %d units, tried to sell %d. (Kept internal drug name)
		fi
	else # لا ينبغي أن يحدث
		echo "خطأ داخلي: إجراء غير صالح '$action' في drug_transaction." ; return 1 # Internal Error: Invalid action '$action' in drug_transaction.
	fi
}

# وظيفة لمعالجة قائمة شراء المخدرات
buy_drugs() {
	local drug_choice="" drug_amount=""
    declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 ) # Internal names/prices
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Order for menu (internal names)

	while true; do
	    clear_screen
        echo "--- تاجر المخدرات (شراء) ---" # Drug Dealer (Buy)
        printf " الموقع: %-15s | المال: \$%d\n" "$location" "$cash" # Location: %-15s | Cash: $%d
        echo "---------------------------"
        echo " المخزون المتاح (سعر السوق الأساسي):" # Available Inventory (Market Base Price):
        local i=1
        for name in "${drug_names[@]}"; do # Iterate internal names
            # عرض سعر السوق الحالي التقريبي؟
            local base_p=${drug_prices[$name]}
            local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) ) / 100) ))
            (( approx_p < 1 )) && approx_p=1
            # عرض الاسم الداخلي
            printf " %d. %-10s (\~$%d/وحدة)\n" "$i" "$name" "$approx_p" # /unit
            ((i++))
        done
        echo "---------------------------"
        printf " %d. مغادرة\n" "$i" # Leave
        echo "---------------------------"
	    read -r -p "اختر المخدر للشراء (رقم): " drug_choice # Choose drug to buy (number):

        if [[ "$drug_choice" == "$i" ]]; then echo "مغادرة التاجر..."; sleep 1; return; fi # Leaving the dealer...
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#drug_names[@]} )); then
		    echo "اختيار غير صالح."; sleep 1; continue # Invalid choice.
	    fi

        local chosen_drug_name="${drug_names[$((drug_choice - 1))]}" # Internal name
        local chosen_drug_price="${drug_prices[$chosen_drug_name]}"

	    read -r -p "أدخل كمية $chosen_drug_name للشراء: " drug_amount # Enter amount of $chosen_drug_name to buy: (Using internal name)

        # drug_transaction يعالج الرسائل للنجاح/الفشل/التحقق
        drug_transaction "buy" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "اضغط Enter..." # Pause after transaction attempt: Press Enter...
    done
}

# وظيفة لمعالجة قائمة بيع المخدرات
sell_drugs() {
    local drug_choice="" drug_amount=""
    declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 ) # أسعار البيع الأساسية (internal names)
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Order (internal names)

    while true; do
	    clear_screen
        echo "--- تاجر المخدرات (بيع) ---" # Drug Dealer (Sell)
        printf " الموقع: %-15s | المال: \$%d\n" "$location" "$cash" # Location: %-15s | Cash: $%d
        echo "--------------------------"
        echo " مخزونك (قيمة البيع التقريبية/وحدة):" # Your Inventory (Approx Sell Value/unit):
        local i=1
        local available_to_sell=() # تتبع العناصر (الأسماء الداخلية) المتاحة للاختيار
        for name in "${drug_names[@]}"; do # Iterate internal names
            local inventory_amount=${drugs[$name]:-0}
            if (( inventory_amount > 0 )); then
                local base_p=${drug_sell_prices[$name]}
                local skill_bonus_p=$(( (skills[drug_dealer]:-1) * 2 ))
                local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) + skill_bonus_p ) / 100) ))
                (( approx_p < 1 )) && approx_p=1
                # عرض الاسم الداخلي
                printf " %d. %-10s (%d وحدة) ~\$%d/وحدة\n" "$i" "$name" "$inventory_amount" "$approx_p" # units, /unit
                available_to_sell+=("$name") # إضافة اسم المخدرات الداخلي الذي يمكن للاعب بيعه
                ((i++))
            fi
        done

        if (( ${#available_to_sell[@]} == 0 )); then
            echo "--------------------------"
            echo "ليس لديك مخدرات للبيع." # You have no drugs to sell.
            read -r -p "اضغط Enter للمغادرة..." ; return # Press Enter to leave...
        fi
        echo "--------------------------"
        printf " %d. مغادرة\n" "$i" # Leave
        echo "--------------------------"

	    read -r -p "اختر المخدر للبيع (رقم): " drug_choice # Choose drug to sell (number):

        if [[ "$drug_choice" == "$i" ]]; then echo "مغادرة التاجر..."; sleep 1; return; fi # Leaving the dealer...
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#available_to_sell[@]} )); then
		    echo "اختيار غير صالح."; sleep 1; continue # Invalid choice.
	    fi

        local chosen_drug_name="${available_to_sell[$((drug_choice - 1))]}" # Internal name
        local chosen_drug_price="${drug_sell_prices[$chosen_drug_name]}"
        local current_inventory=${drugs[$chosen_drug_name]}

	    read -r -p "بيع كم وحدة من $chosen_drug_name؟ (الحد الأقصى: $current_inventory): " drug_amount # Sell how many units of $chosen_drug_name? (Max: $current_inventory): (Using internal name)

        # drug_transaction يعالج الرسائل للنجاح/الفشل/التحقق
        drug_transaction "sell" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "اضغط Enter..." # Pause after transaction attempt: Press Enter...
    done
}

# وظيفة لتشغيل الموسيقى (نسخة قوية مع إصلاح stty echo)
play_music() {
    # 1. التحقق من المتطلب الأساسي: أمر mpg123
    if ! $mpg123_available; then # استخدام العلامة العامة التي تم التحقق منها عند البدء
        echo "تشغيل الموسيقى معطل: الأمر 'mpg123' غير موجود."; read -r -p "اضغط Enter..."; return 1; # Music playback disabled: 'mpg123' command not found. Press Enter...
    fi

    # 2. تحديد دليل الموسيقى والعثور على الملفات
    local music_dir="$BASEDIR/music"
    local music_files=()
    local original_ifs="$IFS" # حفظ IFS

    if [[ ! -d "$music_dir" ]]; then
        echo "خطأ: دليل الموسيقى '$music_dir' غير موجود!"; read -r -p "اضغط Enter..."; return 1; # Error: Music directory '$music_dir' not found! Press Enter...
    fi

    # استخدام find واستبدال العملية لمعالجة الملفات بشكل أكثر أمانًا
    while IFS= read -r -d $'\0' file; do
        music_files+=("$file")
    done < <(find "$music_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) -print0 2>/dev/null) # البحث عن .mp3 و .MP3
    IFS="$original_ifs" # استعادة IFS

    if (( ${#music_files[@]} == 0 )); then
        echo "لم يتم العثور على ملفات .mp3 في '$music_dir'."; read -r -p "اضغط Enter..."; return 1; # No .mp3 files found in '$music_dir'. Press Enter...
    fi

    # 3. حلقة مشغل الموسيقى
    local choice_stop="ق" choice_back="ع" music_choice="" # إيقاف | عودة
    local mpg123_log="/tmp/bta_mpg123_errors.$$.log" # سجل فريد لكل جلسة

    while true; do
        clear_screen
        echo "--- مشغل الموسيقى ---" # Music Player
        echo " دليل الموسيقى: $music_dir" # Music Directory:
        echo "----------------------------------------"
        local current_status="متوقف" current_song_name="" # Stopped
        if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
            current_song_name=$(ps -p "$music_pid" -o args= 2>/dev/null | sed 's/.*mpg123 [-q]* //; s/ *$//' || echo "تشغيل مقطع") # Playing Track
            [[ -z "$current_song_name" ]] && current_song_name="تشغيل مقطع" # Playing Track
            current_status="تشغيل: $(basename "$current_song_name") (PID: $music_pid)" # Playing: ... (PID: ...)
        else
            [[ -n "$music_pid" ]] && music_pid="" # مسح PID القديم
            current_status="متوقف" # Stopped
        fi
        echo " الحالة: $current_status" # Status:
        echo "----------------------------------------"
        echo " المقاطع المتاحة:" # Available Tracks:
        for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
        echo "----------------------------------------"
        printf " [%s] إيقاف الموسيقى | [%s] العودة إلى اللعبة\n" "$choice_stop" "$choice_back" # Stop Music | Back to Game
        echo "----------------------------------------"

        # التأكد من أن صدى الطرفية قيد التشغيل قبل هذه المطالبة
        stty echo
        read -r -p "أدخل الاختيار (رقم، ق، ع): " music_choice # Enter choice (number, s, b): -> ق, ع

        case "$music_choice" in
            "$choice_stop" | "q" | "ق") # Check for 'ق' too
                if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                    echo "إيقاف الموسيقى (PID: $music_pid)..." # Stopping music (PID: $music_pid)...
                    kill "$music_pid" &>/dev/null; sleep 0.2
                    if kill -0 "$music_pid" &>/dev/null; then kill -9 "$music_pid" &>/dev/null; fi
                    wait "$music_pid" 2>/dev/null; music_pid=""; echo "تم إيقاف الموسيقى." # Music stopped.
                else echo "لا توجد موسيقى قيد التشغيل حاليًا."; fi # No music is currently playing.
                # التأكد من استعادة الصدى بعد محاولة الإيقاف
                stty echo
                sleep 1 # توقف قصير
                ;; # ستتكرر الحلقة وتعرض القائمة المحدثة
            "$choice_back" | "b" | "ع") # Check for 'ع' too
                echo "العودة إلى اللعبة..."; sleep 1; break # Returning to game... # الخروج من حلقة الموسيقى
                ;;
            *)
                if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
                    local selected_track="${music_files[$((music_choice - 1))]}"
                    if [[ ! -f "$selected_track" ]]; then echo "خطأ: الملف '$selected_track' غير موجود!"; sleep 2; continue; fi # Error: File '$selected_track' not found!

                    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                        echo "إيقاف المقطع السابق..."; kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""; sleep 0.2; # Stopping previous track...
                    fi

                    echo "محاولة تشغيل: $(basename "$selected_track")" # Attempting to play: ...

                    # --- أمر التشغيل (بدون Subshell) ---
                    echo "--- BTA Log $(date) --- تشغيل: $selected_track" >> "$mpg123_log" # Playing:
                    mpg123 -q "$selected_track" 2>> "$mpg123_log" &
                    # ---------------------------------

                    local new_pid=$!
                    sleep 0.5 # إعطائها لحظة للبدء أو الفشل

                    if kill -0 "$new_pid" 2>/dev/null; then
                        music_pid=$new_pid; echo "بدأ التشغيل (PID: $music_pid)." # Playback started (PID: $music_pid).
                        # لا تتوقف هنا، دع الحلقة تتكرر لإظهار الحالة
                    else
                        echo "خطأ: فشل في بدء عملية mpg123 لـ $(basename "$selected_track")." # Error: Failed to start mpg123 process for ...
                        echo "       تحقق من السجل بحثًا عن الأخطاء (إن وجدت): $mpg123_log" # Check log for errors (if any):
                        if [[ -f "$mpg123_log" ]]; then
                            echo "--- الأسطر الأخيرة من السجل ---"; tail -n 5 "$mpg123_log"; echo "-------------------------" # Last lines of log
                        fi
                        music_pid=""; read -r -p "اضغط Enter..." # Pause: Press Enter...
                    fi
                else
                    echo "اختيار غير صالح '$music_choice'." # Invalid choice '$music_choice'.
                    sleep 1
                fi;;
        esac
    done
    # تنظيف ملف السجل لهذه الجلسة عند الخروج من مشغل الموسيقى؟ اختياري.
    # rm -f "$mpg123_log"
}


# حفظ حالة اللعبة إلى ملف (أكثر قوة)
save_game() {
    local save_path="$BASEDIR/$SAVE_DIR" # استخدام المسار الكامل لدليل الحفظ
    mkdir -p "$save_path" || { echo "خطأ: تعذر إنشاء دليل الحفظ '$save_path'."; read -r -p "اضغط Enter..."; return 1; } # Error: Could not create save directory '$save_path'. Press Enter...

    echo "جاري حفظ حالة اللعبة..." # Saving game state...
    # تحديد مسارات الملفات
    local player_file="$save_path/player_name.sav"
    local loc_file="$save_path/location.sav"
    local cash_file="$save_path/cash.sav"
    local health_file="$save_path/health.sav"
    local armor_file="$save_path/body_armor_equipped.sav"
    local guns_file="$save_path/guns.sav" # Stores internal English names
    local items_file="$save_path/items.sav" # Stores internal English names
    local drugs_file="$save_path/drugs.sav" # Stores internal English keys
    local skills_file="$save_path/skills.sav" # Stores internal English keys
    local temp_ext=".tmp$$" # امتداد مؤقت فريد

    # وظيفة للحفظ الذري (الكتابة إلى مؤقت، ثم إعادة التسمية)
    save_atomic() {
        local content="$1" file_path="$2" temp_file="${file_path}${temp_ext}"
        printf '%s\n' "$content" > "$temp_file" && mv "$temp_file" "$file_path" || {
            echo "خطأ في حفظ الملف: $file_path"; rm -f "$temp_file"; return 1; # Error saving file: $file_path
        }
        return 0
    }

    # --- حفظ المتغيرات البسيطة ---
    save_atomic "$player_name" "$player_file" || return 1
	save_atomic "$location" "$loc_file" || return 1
	save_atomic "$cash" "$cash_file" || return 1
	save_atomic "$health" "$health_file" || return 1
    save_atomic "$body_armor_equipped" "$armor_file" || return 1

    # --- حفظ المصفوفات المفهرسة (الأسماء الداخلية) ---
    printf '%s\n' "${guns[@]}" > "$guns_file$temp_ext" && mv "$guns_file$temp_ext" "$guns_file" || { echo "خطأ في حفظ الأسلحة."; rm -f "$guns_file$temp_ext"; return 1; } # Error saving guns.
	printf '%s\n' "${items[@]}" > "$items_file$temp_ext" && mv "$items_file$temp_ext" "$items_file" || { echo "خطأ في حفظ العناصر."; rm -f "$items_file$temp_ext"; return 1; } # Error saving items.

    # --- حفظ المصفوفات الترابطية (المفاتيح الداخلية) ---
	# المخدرات
    : > "$drugs_file$temp_ext" # إنشاء/مسح الملف المؤقت
	for key in "${!drugs[@]}"; do printf "%s %s\n" "$key" "${drugs[$key]}" >> "$drugs_file$temp_ext"; done
    if [[ -f "$drugs_file$temp_ext" ]]; then mv "$drugs_file$temp_ext" "$drugs_file"; else echo "خطأ في كتابة ملف المخدرات المؤقت."; return 1; fi # Error writing drugs temp file.

	# المهارات
    : > "$skills_file$temp_ext"
	for key in "${!skills[@]}"; do printf "%s %s\n" "$key" "${skills[$key]}" >> "$skills_file$temp_ext"; done
    if [[ -f "$skills_file$temp_ext" ]]; then mv "$skills_file$temp_ext" "$skills_file"; else echo "خطأ في كتابة ملف المهارات المؤقت."; return 1; fi # Error writing skills temp file.

	echo "تم حفظ اللعبة بنجاح في '$save_path'." # Game saved successfully to '$save_path'.
	read -r -p "اضغط Enter للمتابعة..." # Press Enter to continue...
    return 0
}

# تحميل حالة اللعبة من ملف (أكثر قوة)
load_game() {
    local load_success=true
    local original_ifs="$IFS"
    local key="" value="" line="" save_file="" # تعريف/مسح المتغيرات المحلية
    local save_path="$BASEDIR/$SAVE_DIR"

    echo "محاولة تحميل اللعبة من '$save_path'..." # Attempting to load game from '$save_path'...

    if [[ ! -d "$save_path" ]]; then
        echo "خطأ: دليل الحفظ '$save_path' غير موجود."; read -r -p "اضغط Enter..."; return 1; # Error: Save directory '$save_path' not found. Press Enter...
    fi

    # --- تحميل المتغيرات البسيطة ---
    save_file="$save_path/player_name.sav"; [[ -f "$save_file" ]] && { read -r player_name < "$save_file" || { >&2 echo "خطأ في قراءة $save_file"; load_success=false; }; } || { >&2 echo "تحذير: $save_file مفقود"; player_name="غير معروف"; load_success=false; } # Error reading $save_file | Warn: $save_file missing | Unknown
    save_file="$save_path/location.sav"; [[ -f "$save_file" ]] && { read -r location < "$save_file" || { >&2 echo "خطأ في قراءة $save_file"; load_success=false; }; } || { >&2 echo "تحذير: $save_file مفقود"; location="Los Santos"; load_success=false; }
    save_file="$save_path/cash.sav"; [[ -f "$save_file" ]] && { read -r cash < "$save_file" || { >&2 echo "خطأ في قراءة $save_file"; load_success=false; }; } || { >&2 echo "تحذير: $save_file مفقود"; cash=0; load_success=false; }
    [[ ! "$cash" =~ ^-?[0-9]+$ ]] && { >&2 echo "تحذير: مال غير صالح '$cash'"; cash=0; load_success=false; } # Warn: Invalid cash '$cash'
    save_file="$save_path/health.sav"; [[ -f "$save_file" ]] && { read -r health < "$save_file" || { >&2 echo "خطأ في قراءة $save_file"; load_success=false; }; } || { >&2 echo "تحذير: $save_file مفقود"; health=100; load_success=false; }
    [[ ! "$health" =~ ^[0-9]+$ ]] && { >&2 echo "تحذير: صحة غير صالحة '$health'"; health=100; load_success=false; } # Warn: Invalid health '$health'
    (( health <= 0 && load_success )) && { >&2 echo "تحذير: الصحة المحملة <= 0"; health=50; } # Warn: Loaded health <= 0
    save_file="$save_path/body_armor_equipped.sav"; [[ -f "$save_file" ]] && { read -r body_armor_equipped < "$save_file" || { >&2 echo "خطأ في قراءة $save_file"; load_success=false; }; } || { >&2 echo "تحذير: $save_file مفقود"; body_armor_equipped=false; load_success=false; }
    [[ "$body_armor_equipped" != "true" && "$body_armor_equipped" != "false" ]] && { >&2 echo "تحذير: درع غير صالح '$body_armor_equipped'"; body_armor_equipped=false; load_success=false; } # Warn: Invalid armor '$body_armor_equipped'

    # --- تحميل المصفوفات المفهرسة (تحميل الأسماء الداخلية) ---
    guns=(); save_file="$save_path/guns.sav"
    if [[ -f "$save_file" ]]; then
         if command -v readarray &> /dev/null; then readarray -t guns < "$save_file";
         else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do guns+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "تحذير: $save_file مفقود"; fi # Warn: $save_file missing

    items=(); save_file="$save_path/items.sav"
    if [[ -f "$save_file" ]]; then
        if command -v readarray &> /dev/null; then readarray -t items < "$save_file";
        else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do items+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "تحذير: $save_file مفقود"; fi # Warn: $save_file missing

    # --- تحميل المصفوفات الترابطية (تحميل المفاتيح الداخلية) ---
    declare -A drugs_loaded=(); save_file="$save_path/drugs.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
            if [[ -n "$key" && -v "default_drugs[$key]" ]]; then # Check against default_drugs keys (internal names)
                 if [[ "$value" =~ ^[0-9]+$ ]]; then drugs_loaded["$key"]="$value"; else
                     >&2 echo "تحذير: كمية مخدرات غير صالحة '$key'='$value'"; drugs_loaded["$key"]=0; load_success=false; fi # Warn: Invalid drug amt '$key'='$value'
            elif [[ -n "$key" ]]; then >&2 echo "تحذير: تخطي مخدر غير معروف '$key'"; fi # Warn: Skipping unknown drug '$key'
        done < "$save_file"
    else >&2 echo "تحذير: $save_file مفقود"; load_success=false; fi # Warn: $save_file missing
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${drugs_loaded[$key]:-${default_drugs[$key]}}; done

    declare -A skills_loaded=(); save_file="$save_path/skills.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
             if [[ -n "$key" && -v "default_skills[$key]" ]]; then # Check against default_skills keys (internal names)
                 if [[ "$value" =~ ^[0-9]+$ ]]; then skills_loaded["$key"]="$value"; else
                     >&2 echo "تحذير: مستوى مهارة غير صالح '$key'='$value'"; skills_loaded["$key"]=1; load_success=false; fi # Warn: Invalid skill lvl '$key'='$value'
             elif [[ -n "$key" ]]; then >&2 echo "تحذير: تخطي مهارة غير معروفة '$key'"; fi # Warn: Skipping unknown skill '$key'
        done < "$save_file"
    else >&2 echo "تحذير: $save_file مفقود"; load_success=false; fi # Warn: $save_file missing
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${skills_loaded[$key]:-${default_skills[$key]}}; done

    # --- الفحص النهائي ---
    IFS="$original_ifs"
    if $load_success; then echo "تم تحميل اللعبة بنجاح."; else # Game loaded successfully.
        echo "تحذير: تم تحميل اللعبة ببيانات مفقودة/غير صالحة. تم استخدام القيم الافتراضية."; fi # Warning: Game loaded with missing/invalid data. Defaults used.
    read -r -p "اضغط Enter لبدء اللعب..." # Press Enter to start playing...
    return 0
}

# --- 4. تهيئة اللعبة والحلقة ---

# وظيفة لتهيئة متغيرات لعبة جديدة
Game_variables() {
	clear_screen
	read -r -p "أدخل اسم اللاعب الخاص بك: " player_name # Enter your player name:
	[[ -z "$player_name" ]] && player_name="هائم" # Wanderer -> هائم
	play_sfx_mpg "new_game"
	location="Los Santos"
	cash=500
	health=100
	guns=() # إعادة تعيين المصفوفات الداخلية
	items=()
    # إعادة تعيين المصفوفات الترابطية باستخدام القيم الافتراضية (المفاتيح الداخلية)
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
    body_armor_equipped=false
	echo "أهلاً بك في Bash Theft Auto يا $player_name!" # Welcome to Bash Theft Auto, $player_name!
    echo "تبدأ في $location بـ \$${cash} وصحة ${health}%." # Starting in $location with $${cash} and ${health}% health.
    read -r -p "اضغط Enter للبدء..." # Press Enter to begin...
}

# وظيفة لإزالة ملفات الحفظ بأمان
remove_save_files() {
    local save_path="$BASEDIR/$SAVE_DIR"
    if [[ -d "$save_path" ]]; then
        echo "حذف ملفات الحفظ السابقة في '$save_path'..." # Deleting previous save files in '$save_path'...
        local found_files=$(find "$save_path" -maxdepth 1 -type f -name '*.sav' -print -delete)
        if [[ -n "$found_files" ]]; then echo "تم حذف ملفات الحفظ القديمة بنجاح."; else echo "لم يتم العثور على ملفات '.sav' للحذف."; fi # Old save files deleted successfully. | No '.sav' files found to delete.
    else
        echo "معلومة: لم يتم العثور على دليل حفظ سابق في '$save_path'." # Info: No previous save directory found at '$save_path'.
    fi
    sleep 1 # توقف قصير
}

# --- قائمة اللعبة الأولية ---
run_initial_menu() {
    while true; do
	    clear_screen
	    echo "=== Bash Theft Auto ==="
	    echo "      القائمة الرئيسية" # Main Menu
        echo "---------------------"
	    echo "1. لعبة جديدة" # 1. New Game
	    echo "2. تحميل لعبة" # 2. Load Game
	    echo "3. الخروج من اللعبة" # 3. Exit Game
        echo "---------------------"
        stty echo # التأكد من تشغيل الصدى للقائمة
	    read -r -p "أدخل اختيارك: " initial_choice # Enter your choice:

	    case "$initial_choice" in
		    1)
                read -r -p "بدء لعبة جديدة؟ سيؤدي هذا إلى حذف أي حفظ موجود. (ن/ل): " confirm # Start new game? This deletes any existing save. (y/n): -> ن/ل
                if [[ "$confirm" == "ن" || "$confirm" == "N" || "$confirm" == "n" ]]; then # Check for Arabic 'ن' or 'n'/'N'
                    remove_save_files
                    Game_variables
                    return 0 # إشارة لبدء حلقة اللعبة
                else echo "تم إلغاء اللعبة الجديدة."; sleep 1; fi ;; # New game cancelled.
		    2)
                if load_game; then return 0; # إشارة لبدء حلقة اللعبة
                else sleep 1; fi ;; # فشل تحميل اللعبة، توقف قبل عرض القائمة مرة أخرى
		    3) cleanup_and_exit ;; # استخدام وظيفة التنظيف
		    *) echo "اختيار غير صالح."; sleep 1 ;; # Invalid choice.
	    esac
    done
}

# --- التنفيذ الرئيسي ---

# تشغيل القائمة الأولية. إذا عادت بنجاح (0)، انتقل إلى الحلقة الرئيسية.
if ! run_initial_menu; then
    echo "الخروج بسبب فشل القائمة الأولية أو طلب المستخدم." # Exiting due to initial menu failure or user request.
    stty echo # التأكد من تشغيل الصدى على أي حال
    exit 1
fi


# --- حلقة اللعبة الرئيسية ---
while true; do
    # التحقق من الصحة عند البدء؛ يعالج الموت/المستشفى ويعيد 1 إذا مات اللاعب
    if check_health; then
        # اللاعب على قيد الحياة، مسح الشاشة وإظهار الحالة/القائمة
        clear_screen
    else
        # تم نقل اللاعب إلى المستشفى، تم التعامل مع الشاشة بالفعل بواسطة check_health/hospitalize_player
        # تحتاج فقط إلى إظهار القائمة الرئيسية مرة أخرى بعد الضغط على Enter
        clear_screen # إظهار الحالة بعد المستشفى
    fi

    # --- عرض القائمة الرئيسية ---
    # ملاحظة: قد تحتاج المحاذاة إلى تعديل لـ RTL
    echo "--- الإجراءات ---" # Actions
    echo "1. السفر              | 6. شراء مخدرات"       # 1. Travel        | 6. Buy Drugs
    echo "2. شراء أسلحة         | 7. بيع مخدرات"        # 2. Buy Guns      | 7. Sell Drugs
    echo "3. المخزون            | 8. استئجار عاهرة"      # 3. Inventory     | 8. Hire Hooker
    echo "4. العمل (قانوني)      | 9. زيارة المستشفى"    # 4. Work (Legal)  | 9. Visit Hospital
    echo "5. العمل (إجرامي)     | 10. سباق شوارع"       # 5. Work (Crime)  | 10. Street Race
    echo "-----------------------------------------"
    echo "S. حفظ اللعبة         | L. تحميل اللعبة"        # S. Save Game     | L. Load Game
    echo "M. مشغل الموسيقى     | A. حول اللعبة"          # M. Music Player  | A. About
    echo "X. الخروج من اللعبة"                           # X. Exit Game
    echo "-----------------------------------------"

    # --- استعادة صدى الطرفية قبل قراءة الإدخال ---
    stty echo
    # --- قراءة اختيار المستخدم ---
    read -r -p "أدخل اختيارك: " choice # Enter your choice:
    # تحويل الاختيار إلى أحرف صغيرة للأوامر
    choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    # --- معالجة الاختيار ---
    case "$choice_lower" in
	    1) # قائمة السفر
            clear_screen; echo "--- وكالة السفر ---" # Travel Agency
            echo "1. Los Santos (\$50) | 2. San Fierro (\$75) | 3. Las Venturas (\$100)";
            echo "4. Vice City (\$150) | 5. Liberty City (\$200) | 6. البقاء هنا"; # Stay Here
            read -r -p "أدخل الاختيار: " city_choice # Enter choice:
            [[ ! "$city_choice" =~ ^[1-6]$ ]] && { echo "اختيار غير صالح."; sleep 1; continue; } # Invalid choice.
            case "$city_choice" in
                1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";;
                3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";;
                5) travel_to 200 "Liberty City";; 6) ;;
            esac;;
	    2) buy_guns;;
	    3) show_inventory;;
	    4) # قائمة العمل القانوني
            clear_screen; echo "--- عمل شريف ---" # Honest Work
            echo "1. سائق تاكسي | 2. توصيل | 3. ميكانيكي | 4. حارس أمن | 5. فنان شارع | 6. رجوع"; # Taxi Driver | Delivery | Mechanic | Security | Performer | Back
            read -r -p "أدخل الاختيار: " job_choice # Enter choice:
            [[ ! "$job_choice" =~ ^[1-6]$ ]] && { echo "اختيار غير صالح."; sleep 1; continue; } # Invalid choice.
            case "$job_choice" in
                1) work_job "سائق تاكسي";; 2) work_job "توصيل";; 3) work_job "ميكانيكي";;
                4) work_job "حارس أمن";; 5) work_job "فنان شارع";; 6) ;;
            esac;;
	    5) # قائمة الأنشطة الإجرامية
            clear_screen; echo "--- الأنشطة الإجرامية ---" # Criminal Activities
            echo "1. سرقة متجر | 2. سرقة سيارة | 3. حرب عصابات | 4. سطو | 5. رجوع"; # Rob Store | Carjack | Gang War | Heist | Back
            read -r -p "أدخل الاختيار: " criminal_choice # Enter choice:
            [[ ! "$criminal_choice" =~ ^[1-5]$ ]] && { echo "اختيار غير صالح."; sleep 1; continue; } # Invalid choice.
            case "$criminal_choice" in
                1) rob_store;; 2) carjack;; 3) gang_war;; 4) heist;; 5) ;;
            esac;;
	    6) buy_drugs;;
	    7) sell_drugs;;
	    8) hire_hooker;;
	    9) visit_hospital;;
        10) street_race;;
	    's') save_game;;
	    'l')
             read -r -p "تحميل اللعبة؟ سيتم فقدان التقدم غير المحفوظ. (ن/ل): " confirm # Load game? Unsaved progress will be lost. (y/n): -> ن/ل
             if [[ "$confirm" == "ن" || "$confirm" == "N" || "$confirm" == "n" ]]; then # Check for Arabic 'ن' or 'n'/'N'
                 load_game # load_game يعالج الرسائل ويستمر في الحلقة
             else echo "تم إلغاء التحميل."; sleep 1; fi ;; # Load cancelled.
	    'm') play_music;;
	    'a') about_music_sfx;;
        'x')
             read -r -p "هل أنت متأكد أنك تريد الخروج؟ (ن/ل): " confirm # Are you sure you want to exit? (y/n): -> ن/ل
             if [[ "$confirm" == "ن" || "$confirm" == "N" || "$confirm" == "n" ]]; then # Check for Arabic 'ن' or 'n'/'N'
                 # اختياري: حفظ تلقائي قبل الخروج؟
                 # read -r -p "حفظ قبل الخروج؟ (ن/ل): " save_confirm
                 # if [[ "$save_confirm" == "ن" || "$save_confirm" == "N" || "$save_confirm" == "n" ]]; then save_game; fi
                 cleanup_and_exit # استخدام وظيفة التنظيف
             fi ;;
	    *) echo "اختيار غير صالح '$choice'."; sleep 1;; # Invalid choice '$choice'.
	esac
    # تستمر الحلقة
done

# لا ينبغي الوصول إليه، ولكن محاولة التنظيف إذا حدث ذلك
cleanup_and_exit

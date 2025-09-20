### Update - Version 2.4.1

Project is back in active development! The latest version includes all the features listed below plus ongoing improvements and bug fixes.

---

### **1. Major New Feature: The Perk System**

The most significant difference is the introduction of a complete **Perk System** to make your character more unique and powerful over time.

*   **Perk Points:** You now earn **1 Perk Point** for every 1000 respect you gain. The script tracks this with new variables (`perk_points` and `last_respect_milestone`).
*   **New "Perks" Menu:** A new option, `(P) Perks`, has been added to the main action menu. This takes you to a dedicated screen where you can spend your points.
*   **Tiered Perks:** Perks are organized into three tiers. You must unlock a certain number of perks from a lower tier to access the more powerful ones above them.
*   **Initial Perks Added:**
    *   **Tier 1:** `Street Negotiator` (shop discounts), `Back Alley Surgeon` (better healing from items), `Grease Monkey` (free vehicle repairs).
    *   **Tier 2:** `Master of Disguise` (less wanted level gain), `Professional Driver` (better race performance).
    *   **Tier 3:** `Charismatic Leader` (cheaper recruit hiring and upkeep).

### **2. Modifications to Existing Gameplay**

The new Perk System is integrated directly into existing game mechanics:

*   **`award_respect()`:** This function was modified to check if you've passed a 1000-respect milestone after gaining respect. If you have, it automatically awards you a Perk Point.
*   **`hospitalize_player()`:** If you have the `Street Negotiator` perk, the hospital bill is now automatically reduced by 10%.
*   **Crime & Wanted Level:** If you have the `Master of Disguise` perk, the amount of wanted level you gain from crimes is reduced.
*   **Street Racing:** The `Professional Driver` perk now gives you a significant advantage in street races.
*   **Gang Management:** The `Charismatic Leader` perk makes hiring and maintaining your crew cheaper.

### **3. Critical Bug Fixes**

This new version fixes several persistent and game-breaking bugs from the previous script:

1.  **Gang War Menu Index (The "0" Bug):**
    *   **Old Script:** The "Select a Territory to Attack" menu incorrectly started its numbering at `0` instead of `1`.
    *   **New Script:** This has been **definitively fixed**. The loop counter is now initialized and incremented correctly, ensuring the menu always displays a clean, 1-based list (`1.`, `2.`, `3.`, etc.).

2.  **Invalid `read` Placeholder:**
    *   **Old Script:** Several functions used `read -r - ...` to parse colon-separated data (like from the recruits array). The hyphen (`-`) is not a valid variable name, which caused errors like the one you saw, where the wrong data was displayed in the gang war menu.
    *   **New Script:** All instances of this have been replaced with the standard underscore (`_`) placeholder (e.g., `read -r _ str _`). This is the correct, portable way to ignore input and makes the script more stable.

3.  **Incorrect Gang War Bonus:**
    *   **Old Script:** In the `initiate_gang_war` function, the bonus strength from recruits was being calculated incorrectly.
    *   **New Script:** This has been fixed to correctly parse the recruit's strength and add the appropriate bonus to your gang's power during a fight.

### **4. System and Data Management**

*   **Save/Load System:** The `save_game` and `load_game` functions have been updated to handle the new Perk System. Your unlocked perks and unspent perk points are now saved and loaded correctly.
*   **Initialization:** The `initialize_world_data` function now properly resets all perk-related variables when you start a new game.

In summary, the new script is a significant upgrade that not only **adds a major new progression system (Perks)** but also **fixes long-standing, critical bugs**, resulting in a more stable, correct, and engaging gameplay experience.


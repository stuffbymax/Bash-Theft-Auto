# Bash-Theft-Auto

## optimalisation news
 
**Key Optimizations and Changes:**

1.  **Plugin Loading:**
    *   Uses `find ... -print0` and `while read -r -d $'\0'` loop for handling filenames with spaces or special characters.
    *   Simplified `if` check for file existence using `[[ -f "$plugin" ]] && source "$plugin"`.
    *   Replaced the `find` command with process substitution, to be faster.

2.  **`printf` for Output:**
    *   Replaced multiple `echo` statements with `printf` for more efficient and readable output formatting. `printf` is generally faster, and allows for precise formatting.
   
3.  **Local Variables:**
    *   Used `local` keyword in functions to avoid unintentional variable collisions and improve the overall code.

4.  **Error Handling:**
    *   Input validation for menu choices in function using regex (`=~ ^[0-9]+$`).
    *   Clearer error messages for invalid inputs.

5. **Function for Item Purchase:**
    * Created a more generic `buy_item` to avoid duplicating code in the  `buy_guns` function.
     * Created a more generic `buy_hospital_item` to avoid duplicating code in the  `visit_hospital` function.
    * Created a more generic `buy_drug` to avoid duplicating code in the  `buy_drugs` function.
     * Created a more generic `sell_drug` to avoid duplicating code in the  `sell_drugs` function.
   
6. **Function for Work Jobs:**
    *  Simplified the `work_job` function, removing redundant logic by using a single function that receives a parameter for the job type to select specific logic using `case` statements, the same for the `street_race`.

7.  **Simplified Health and Damage Logic:**
     *  Simplified logic for random numbers.

8.  **Readability:**
    *   Improved comments and spacing for better code clarity.
    *   Use `read -r` instead of just `read`.
    *   Use clear variable names to better understand what they represent.

9. **Arrays:**
  * Saved and loaded arrays using `printf` and `read -r -a`.

10. **Logic:**
    *   Simplified nested `if` statements.
    *   Used `(( condition )) && action` syntax for concise conditional execution.
    
11. **tabs over spaces:**
    *   used tabs for optimalization saved about 4KB

**How to Use:**

1.  **Save:** Save the code as a `.sh` file (e.g., `game.sh`).
2.  **Make Executable:** `chmod +x game.sh`
3.  **Run:** `./game.sh`

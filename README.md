1. Copy this script into a Script object in ServerScriptService in your Roblox game.
2. The system will automatically track player activity and detect when a player is AFK (Away From Keyboard).
3. To check if a player is currently AFK, call:
   IsPlayerAFK(player)
4. To set the AFK timeout (how many seconds of inactivity before a player is considered AFK), change the AFK_TIMEOUT variable.
5. To get notified when a player goes AFK or returns, customize the onAFKStatusChanged(player, isAFK) function.
6. The system automatically resets AFK status on player input (movement, jumping, chatting, etc.).
7. To enable AFK protection (no autokick, invincibility), set AFK_PROTECTION_ENABLED = true at the top of the script.

--[[
AFK Detection System for Roblox
Author: Vain_ie

--- HOW TO IMPLEMENT ---
1. Copy this script into a Script object in ServerScriptService in your Roblox game.
2. The system will automatically track player activity and detect when a player is AFK (Away From Keyboard).
3. To check if a player is currently AFK, call:
   IsPlayerAFK(player)
4. To set the AFK timeout (how many seconds of inactivity before a player is considered AFK), change the AFK_TIMEOUT variable.
5. To get notified when a player goes AFK or returns, customize the onAFKStatusChanged(player, isAFK) function.
6. The system automatically resets AFK status on player input (movement, jumping, chatting, etc.).
7. To enable AFK protection (no autokick, invincibility), set AFK_PROTECTION_ENABLED = true at the top of the script.

--- END OF TUTORIAL ---

Credits: System created by Vain_ie

--- EXPLANATION OF EVERY SECTION ---

-- AFK_PROTECTION_ENABLED: If true, AFK players are not kicked and are made invincible. If false, normal autokick occurs.
-- Players: Roblox service to access all players in the game.
-- AFK_TIMEOUT: How many seconds of inactivity before a player is considered AFK.
-- LONG_AFK_TIMEOUT: How many seconds before a long AFK triggers (for autokick or invincibility).
-- playerAFK: Table storing each player's last activity time and AFK status.
-- initAFK(player): Initializes AFK tracking for a player (called on join/respawn).
-- IsPlayerAFK(player): Returns true if the player is currently AFK.
-- updateActivity(player): Updates a player's last activity time and removes AFK status if needed (called on any input).
-- setAFKBillboard(player, show): Shows or hides an 'AFK' text above the player's head using a BillboardGui.
-- onLongAFK(player): Called when a player is AFK for a long time. Kicks or makes them invincible depending on AFK_PROTECTION_ENABLED.
-- removeAFKInvincibility(player): Removes invincibility from a player (when they return from AFK).
-- onAFKStatusChanged(player, isAFK): Called when a player's AFK status changes. Handles notifications, AFK text, and invincibility.
-- SetPlayerAFK(player, isAFK): Manually sets a player's AFK status (e.g., for a /afk command).
-- GetAllAFKPlayers(): Returns a list of all currently AFK players.
-- ReplicatedStorage/AFKActivityEvent: Optional RemoteEvent for client-side activity reporting (for more accurate detection).
-- afkChecker(): Main loop that checks all players for AFK status and triggers onLongAFK if needed.
-- PlayerAdded/CharacterAdded: Sets up AFK tracking and input listeners for new players and respawns.
-- PlayerRemoving: Cleans up AFK data when a player leaves.
-- spawn(afkChecker): Starts the AFK checking loop in the background.

--- END OF EXPLANATION ---
]]

-- AFK Detection System for Roblox
-- This script detects when a player is AFK (inactive) and provides hooks for custom actions.

-- Get the Players service to access all players in the game
local Players = game:GetService("Players")

-- How many seconds of inactivity before a player is considered AFK
local AFK_TIMEOUT = 60 -- seconds

-- Table to store each player's last activity time and AFK status
local playerAFK = {}

-- === AFK Protection Settings ===
AFK_PROTECTION_ENABLED = false -- Set to true to disable autokick and make AFK players invincible
-- =============================

-- Function to initialize AFK tracking for a player
local function initAFK(player)
    playerAFK[player.UserId] = {
        LastActive = os.time(),
        IsAFK = false
    }
end

-- Function to check if a player is currently AFK
function IsPlayerAFK(player)
    local data = playerAFK[player.UserId]
    if data then
        return data.IsAFK
    end
    return false
end

-- Function to update a player's activity (call on any input)
local function updateActivity(player)
    local data = playerAFK[player.UserId]
    if data then
        data.LastActive = os.time()
        if data.IsAFK then
            data.IsAFK = false
            onAFKStatusChanged(player, false)
        end
    end
end

-- Function to show or hide AFK text above a player's head (Roblox Studio compatible)
function setAFKBillboard(player, show)
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    local tag = head:FindFirstChild("AFKBillboard")
    if show then
        if not tag then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "AFKBillboard"
            billboard.Size = UDim2.new(0, 100, 0, 40)
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.Adornee = head
            billboard.AlwaysOnTop = true
            billboard.Parent = head
            -- BillboardGui must have a parent of PlayerGui or workspace, so we use head as parent (works in Studio)
            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.Text = "AFK"
            textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            textLabel.TextStrokeTransparency = 0.5
            textLabel.Font = Enum.Font.SourceSansBold
            textLabel.TextScaled = true
            textLabel.Parent = billboard
        end
    else
        if tag then
            tag:Destroy()
        end
    end
end

-- Advanced: Add a callback for when a player has been AFK for a long time (e.g., auto-kick or invincibility)
local LONG_AFK_TIMEOUT = 900 -- 15 minutes
function onLongAFK(player)
    if AFK_PROTECTION_ENABLED then
        -- Make player invincible while AFK
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.Health = player.Character.Humanoid.MaxHealth
            player.Character.Humanoid:SetAttribute("AFKInvincible", true)
            -- Optional: Connect to HealthChanged to prevent damage
            if not player.Character.Humanoid:FindFirstChild("AFKInvincibleConnection") then
                local conn = player.Character.Humanoid.HealthChanged:Connect(function()
                    if AFK_PROTECTION_ENABLED and IsPlayerAFK(player) then
                        player.Character.Humanoid.Health = player.Character.Humanoid.MaxHealth
                    end
                end)
                local tag = Instance.new("ObjectValue")
                tag.Name = "AFKInvincibleConnection"
                tag.Value = conn
                tag.Parent = player.Character.Humanoid
            end
        end
    else
        -- Default: kick the player for being AFK too long
        player:Kick("You were kicked for being AFK too long.")
    end
end

-- Remove invincibility when player is no longer AFK or protection is off
function removeAFKInvincibility(player)
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid:SetAttribute("AFKInvincible", false)
        local tag = player.Character.Humanoid:FindFirstChild("AFKInvincibleConnection")
        if tag and tag.Value then
            tag.Value:Disconnect()
            tag:Destroy()
        end
    end
end

-- Update onAFKStatusChanged to remove invincibility when player returns
function onAFKStatusChanged(player, isAFK)
    if isAFK then
        print(player.Name .. " is now AFK!")
        setAFKBillboard(player, true)
    else
        print(player.Name .. " is no longer AFK!")
        setAFKBillboard(player, false)
        removeAFKInvincibility(player)
    end
end

-- Function to manually set a player as AFK (e.g., for a /afk command)
function SetPlayerAFK(player, isAFK)
    local data = playerAFK[player.UserId]
    if data then
        if data.IsAFK ~= isAFK then
            data.IsAFK = isAFK
            onAFKStatusChanged(player, isAFK)
            if not isAFK then
                data.LastActive = os.time()
            end
        end
    end
end

-- Function to get a list of all currently AFK players
function GetAllAFKPlayers()
    local afkList = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if IsPlayerAFK(player) then
            table.insert(afkList, player)
        end
    end
    return afkList
end

-- Advanced: Add a RemoteEvent for client-side activity reporting (for more accurate detection)
-- Place a RemoteEvent named "AFKActivityEvent" in ReplicatedStorage if you want to use this
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local activityEvent = ReplicatedStorage:FindFirstChild("AFKActivityEvent")
if activityEvent then
    activityEvent.OnServerEvent:Connect(function(player)
        updateActivity(player)
    end)
end

-- Main function: check all players for AFK status
local function afkChecker()
    while true do
        for _, player in ipairs(Players:GetPlayers()) do
            local data = playerAFK[player.UserId]
            if data then
                local afkDuration = os.time() - data.LastActive
                if not data.IsAFK and afkDuration >= AFK_TIMEOUT then
                    data.IsAFK = true
                    onAFKStatusChanged(player, true)
                end
                if data.IsAFK and afkDuration >= LONG_AFK_TIMEOUT then
                    onLongAFK(player)
                end
            end
        end
        wait(5) -- Check every 5 seconds
    end
end

-- Listen for new players and set up AFK tracking
Players.PlayerAdded:Connect(function(player)
    initAFK(player)
    player.CharacterAdded:Connect(function(char)
        initAFK(player)
        -- Wait for head to exist before setting billboard
        local head = nil
        while not head do
            head = char:FindFirstChild("Head")
            if not head then wait(0.1) end
        end
        if IsPlayerAFK(player) then
            setAFKBillboard(player, true)
        end
    end)
    -- Listen for player input (movement, jumping, chatting, etc.)
    player.Chatted:Connect(function()
        updateActivity(player)
    end)
    -- For movement/jumping, use Character events
    player.CharacterAdded:Connect(function(character)
        if character:FindFirstChild("Humanoid") then
            character.Humanoid.Running:Connect(function(speed)
                if speed > 0 then
                    updateActivity(player)
                end
            end)
            character.Humanoid.Jumping:Connect(function()
                updateActivity(player)
            end)
        end
    end)
end)

-- When a player leaves, remove their AFK data
Players.PlayerRemoving:Connect(function(player)
    playerAFK[player.UserId] = nil
end)

-- Start the AFK checker loop in the background
spawn(afkChecker)

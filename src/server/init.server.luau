--!strict

local Players = game:GetService("Players")
local ServerScriptSevice = game:GetService("ServerScriptService")

local PlayerMechHandler = require(ServerScriptSevice.Server.PlayerMechHandler)

PlayerMechHandler.initialize()
-- Players.PlayerRemoving:Connect(PlayerMechHandler.OnPlayerRemoving)
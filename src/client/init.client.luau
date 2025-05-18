--!strict

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local MechController = require(StarterPlayer.StarterPlayerScripts.Client.MechController)
MechController.initialize()

local PilotingStateChangedEvent: RemoteEvent = ReplicatedStorage:WaitForChild("PilotingStateChangedEvent")

PilotingStateChangedEvent.OnClientEvent:Connect(function(isPiloting: boolean)
    print(string.format("[InitClient] PilotingStateChangedEvent 수신: isPiloting = %s", tostring(isPiloting)))
    MechController.setPiloting(isPiloting)

	if isPiloting then
		-- 로봇에 탑승했을 때 추가적으로 할 클라이언트 측 작업 (예: 마우스 커서 잠금)
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		print("[InitClient] 마우스 커서 잠금 (LockCenter)")
	else
		-- 로봇에서 내렸을 때 추가적으로 할 클라이언트 측 작업 (예: 마우스 커서 기본값으로)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		print("[InitClient] 마우스 커서 기본값 (Default)")
	end
end)

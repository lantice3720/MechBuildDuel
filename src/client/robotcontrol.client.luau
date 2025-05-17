-- 위치: StarterPlayer > StarterPlayerScripts > ClientScripts > RobotControlClient.client.lua
-- 기능: 플레이어의 키보드 입력을 감지하여 서버로 로봇 이동 이벤트를 전송합니다.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local robotMoveEvent = ReplicatedStorage:WaitForChild("RobotMoveEvent") -- 서버와 통신할 RemoteEvent

local moveDirection = Vector3.new(0, 0, 0) -- 현재 이동 방향
local isMoving = false

-- 키 입력 처리 함수
local function onInputBegan(input, gameProcessedEvent)
	if gameProcessedEvent then return end -- 게임 내부 UI 등이 입력을 이미 처리했다면 무시

	if input.KeyCode == Enum.KeyCode.W then
		moveDirection = moveDirection + Vector3.new(0, 0, -1) -- 전진
		isMoving = true
	elseif input.KeyCode == Enum.KeyCode.S then
		moveDirection = moveDirection + Vector3.new(0, 0, 1) -- 후진
		isMoving = true
	elseif input.KeyCode == Enum.KeyCode.A then
		moveDirection = moveDirection + Vector3.new(-1, 0, 0) -- 좌회전 (여기서는 좌로 이동으로 단순화)
		isMoving = true
	elseif input.KeyCode == Enum.KeyCode.D then
		moveDirection = moveDirection + Vector3.new(1, 0, 0) -- 우회전 (여기서는 우로 이동으로 단순화)
		isMoving = true
	end
end

local function onInputEnded(input, gameProcessedEvent)
	if gameProcessedEvent then return end

	if input.KeyCode == Enum.KeyCode.W then
		moveDirection = moveDirection - Vector3.new(0, 0, -1)
	elseif input.KeyCode == Enum.KeyCode.S then
		moveDirection = moveDirection - Vector3.new(0, 0, 1)
	elseif input.KeyCode == Enum.KeyCode.A then
		moveDirection = moveDirection - Vector3.new(-1, 0, 0)
	elseif input.KeyCode == Enum.KeyCode.D then
		moveDirection = moveDirection - Vector3.new(1, 0, 0)
	end

	if moveDirection == Vector3.new(0,0,0) then
		isMoving = false
	end
end

-- 매 프레임마다 이동 방향을 서버로 전송 (움직임이 있을 때만)
RunService.RenderStepped:Connect(function()
	if isMoving then
		-- 이동 방향 벡터의 크기를 1로 정규화 (대각선 이동 시 속도 빨라짐 방지)
		local normalizedDir = moveDirection.Magnitude > 0 and moveDirection.Unit or Vector3.new(0,0,0)
		robotMoveEvent:FireServer(normalizedDir)
	else
		-- 움직임이 멈췄을 때도 서버에 알릴 수 있습니다 (필요하다면).
		-- 여기서는 단순화를 위해 움직일 때만 전송합니다.
		-- 정지 신호를 보내려면: robotMoveEvent:FireServer(Vector3.new(0,0,0))
	end
end)

-- 입력 이벤트 연결
UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

print("로봇 조종 클라이언트 스크립트 로드됨")

--!strict
-- 플레이어의 기체 조작을 서버로 넘김

export type MechController = {
	initialize: () -> (),
	setPiloting: (piloting: boolean) -> (),
}

local MechController: MechController = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

-- 서버로 입력 상태를 전송할 RemoteEvent (ReplicatedStorage에 미리 만들어두어야 함)
local MechControlEvent: RemoteEvent -- 실제로는 ReplicatedStorage:WaitForChild("MechControlEvent")

-- 현재 입력 상태를 저장하는 테이블
local currentInputs = {
	Forward = 0, -- -1 (뒤), 0 (정지), 1 (앞)
	Strafe = 0,  -- -1 (왼쪽), 0 (정지), 1 (오른쪽)
	Yaw = 0,     -- 마우스 좌우 움직임에 따른 회전 값 (선택 사항, 카메라 기반 회전일 수도 있음)
	Pitch = 0,   -- 마우스 상하 움직임에 따른 포탑/팔 각도 값 (선택 사항)
	Jump = false,
	Boost = false,
	PrimaryFire = false,
	SecondaryFire = false,
}

local isPiloting = false -- 현재 플레이어가 로봇에 탑승 중인지 여부
local lastSentInputs = {} -- 마지막으로 서버에 전송한 입력 (불필요한 전송 방지용)

-- 마우스 감도 설정 (조절 가능)
local MOUSE_SENSITIVITY_X = 0.05
local MOUSE_SENSITIVITY_Y = 0.03

-- 입력 처리 함수들
local function handleInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or not isPiloting then return end -- 게임 UI가 처리했거나, 로봇 탑승 중이 아니면 무시

	if input.KeyCode == Enum.KeyCode.W then
		currentInputs.Forward = 1
	elseif input.KeyCode == Enum.KeyCode.S then
		currentInputs.Forward = -1
	elseif input.KeyCode == Enum.KeyCode.A then
		currentInputs.Strafe = -1
	elseif input.KeyCode == Enum.KeyCode.D then
		currentInputs.Strafe = 1
	elseif input.KeyCode == Enum.KeyCode.Space then
		currentInputs.Jump = true
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		currentInputs.Boost = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		currentInputs.PrimaryFire = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		currentInputs.SecondaryFire = true
	end
end

local function handleInputEnded(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or not isPiloting then return end

	if input.KeyCode == Enum.KeyCode.W and currentInputs.Forward == 1 then
		currentInputs.Forward = 0
	elseif input.KeyCode == Enum.KeyCode.S and currentInputs.Forward == -1 then
		currentInputs.Forward = 0
	elseif input.KeyCode == Enum.KeyCode.A and currentInputs.Strafe == -1 then
		currentInputs.Strafe = 0
	elseif input.KeyCode == Enum.KeyCode.D and currentInputs.Strafe == 1 then
		currentInputs.Strafe = 0
	elseif input.KeyCode == Enum.KeyCode.Space then
		currentInputs.Jump = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		currentInputs.Boost = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		currentInputs.PrimaryFire = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		currentInputs.SecondaryFire = false
	end
end

local function handleMouseMovement(input: InputObject)
	if not isPiloting or UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		-- 마우스가 잠겨있지 않거나, 탑승 중이 아니면 시점 변경 로직을 실행하지 않음
		return
	end
	
	-- 마우스 델타(이동량)를 사용하여 Yaw 및 Pitch 업데이트
	-- 이 값들은 보통 캐릭터나 카메라 회전에 직접 사용되거나, 서버로 전송하여 서버가 처리
	currentInputs.Yaw = input.Delta.X * MOUSE_SENSITIVITY_X 
	currentInputs.Pitch = input.Delta.Y * MOUSE_SENSITIVITY_Y
	-- print(string.format("Mouse Delta: Yaw=%.2f, Pitch=%.2f", currentInputs.Yaw, currentInputs.Pitch))
end

-- 입력 상태가 변경되었는지 확인하는 함수
local function haveInputsChanged(): boolean
	for key, value in pairs(currentInputs) do
		if lastSentInputs[key] ~= value then
			return true
		end
	end
	-- 마우스 움직임은 매번 변경될 수 있으므로, Yaw/Pitch는 별도 처리하거나 항상 보낼 수 있음
	-- 여기서는 단순화를 위해 Yaw/Pitch가 0이 아니면 변경된 것으로 간주
	if currentInputs.Yaw ~= 0 or currentInputs.Pitch ~= 0 then
		return true
	end
	return false
end

-- 현재 입력 상태를 복사하여 lastSentInputs에 저장
local function recordSentInputs()
	for key, value in pairs(currentInputs) do
		lastSentInputs[key] = value
	end
	-- Yaw와 Pitch는 매 프레임 후 0으로 리셋 (델타 값이므로)
	lastSentInputs.Yaw = 0 
	lastSentInputs.Pitch = 0
end

-- 매 프레임 실행되어 입력 상태를 서버로 전송
local function onRenderStep(dt: number)
	if not isPiloting then return end

	if haveInputsChanged() then
		if MechControlEvent then
			MechControlEvent:FireServer(currentInputs)
			-- print("[MechController] Inputs sent to server:", currentInputs)
		else
			warn("[MechController] MechControlEvent가 설정되지 않아 서버로 입력을 전송할 수 없습니다.")
		end
		recordSentInputs()
	end

	-- 마우스 델타는 매 프레임 누적되지 않도록 리셋
	currentInputs.Yaw = 0
	currentInputs.Pitch = 0
end

-- 공개 함수
function MechController.initialize()
	print("[MechController] 로봇 조종 시스템 초기화 중...")

	-- RemoteEvent 연결 시도
	local eventInstance = ReplicatedStorage:FindFirstChild("MechControlEvent")
	if eventInstance and eventInstance:IsA("RemoteEvent") then
		MechControlEvent = eventInstance
		print("[MechController] MechControlEvent 연결됨.")
	else
		warn("[MechController] ReplicatedStorage에 MechControlEvent라는 이름의 RemoteEvent를 찾을 수 없습니다. 서버 통신이 작동하지 않습니다.")
	end

	UserInputService.InputBegan:Connect(handleInputBegan)
	UserInputService.InputEnded:Connect(handleInputEnded)
	UserInputService.InputChanged:Connect(function(input, gameProcessedEvent) -- 마우스 움직임 등
		if gameProcessedEvent or not isPiloting then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			handleMouseMovement(input)
		end
	end)

	RunService.RenderStepped:Connect(onRenderStep) -- 매 프레임 입력 전송
	print("[MechController] 입력 리스너 및 RenderStepped 연결됨.")
end

-- 플레이어가 로봇에 탑승하거나 내릴 때 호출될 함수
function MechController.setPiloting(piloting: boolean)
	print("setPiloting called: " .. tostring(piloting))
	isPiloting = piloting
	if isPiloting then
		print("[MechController] 로봇 탑승 시작. 입력 활성화.")
		-- 필요하다면 마우스 잠금 등 추가 설정
		-- UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter -- 1인칭 시점 등에서 사용
	else
		print("[MechController] 로봇 탑승 종료. 입력 비활성화.")
		-- 모든 입력 상태 초기화
		for k, _ in pairs(currentInputs) do
			if type(currentInputs[k]) == "number" then
				currentInputs[k] = 0
			elseif type(currentInputs[k]) == "boolean" then
				currentInputs[k] = false
			end
		end
		if MechControlEvent then -- 탑승 종료 시 마지막으로 정지 신호 전송
			MechControlEvent:FireServer(currentInputs)
		end
		recordSentInputs()
		-- UserInputService.MouseBehavior = Enum.MouseBehavior.Default -- 마우스 잠금 해제
	end
end

return MechController

--!strict
-- TODO: ModuleScript 형태로 재가공

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService") -- 물리 업데이트 루프용 (선택 사항)

local MechControlEvent: RemoteEvent = ReplicatedStorage:WaitForChild("MechControlEvent")

local MECH_MOVE_FORCE_MULTIPLIER = 2000 -- 로봇의 질량에 따라 조절 필요
local MECH_STRAFE_FORCE_MULTIPLIER = 1500
local MECH_TURN_TORQUE_MULTIPLIER = 20000
local MECH_MAX_SPEED = 30
local MECH_MAX_TURN_SPEED = math.rad(90) -- 초당 90도

-- 각 플레이어의 현재 로봇과 물리 객체를 저장 (선택적 최적화)
local activeRobotPhysics: {[Player]: {Model: Model, PrimaryPart: BasePart, TargetVelocity: Vector3, TargetAngularVelocity: Vector3}} = {}

local function getPilotedMechAndPrimaryPart(player: Player): (Model?, BasePart?)
	local character = player.Character
	if not character then return nil, nil end

	local humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Sit and humanoid.SeatPart and humanoid.SeatPart.Parent and humanoid.SeatPart.Parent:IsA("Model")) then
		return nil, nil
	end
	
	local mechModel: Model = humanoid.SeatPart.Parent
	if not mechModel.PrimaryPart then
		warn(string.format("[RobotMovementServer] %s가 탑승한 로봇 %s에 PrimaryPart가 없습니다.", player.Name, mechModel.Name))
		return nil, nil
	end
	return mechModel, mechModel.PrimaryPart
end


local function onMechControlReceived(player: Player, inputs: table)
	local mechModel, mechPrimaryPart = getPilotedMechAndPrimaryPart(player)
	if not (mechModel and mechPrimaryPart) then
		-- 플레이어가 로봇에 탑승 중이 아니거나 로봇 구성이 잘못됨
		if activeRobotPhysics[player] then -- 이전에 제어하던 정보가 있다면 초기화
			activeRobotPhysics[player].TargetVelocity = Vector3.new(0,0,0)
			activeRobotPhysics[player].TargetAngularVelocity = Vector3.new(0,0,0)
		end
		return 
	end

	-- 입력 값 해석
	local forwardInput: number = inputs.Forward or 0
	local strafeInput: number = inputs.Strafe or 0
	local yawInput: number = inputs.Yaw or 0 -- 마우스 좌우 이동량 (프레임 델타)
	-- local pitchInput: number = inputs.Pitch or 0 -- 마우스 상하 (팔/포탑용, 여기선 미사용)
	local jumpInput: boolean = inputs.Jump or false
	local boostInput: boolean = inputs.Boost or false

	-- 1. 목표 선형 속도 계산 (로봇의 현재 앞/옆 방향 기준)
	local moveDirectionRelative = Vector3.new(strafeInput, 0, -forwardInput) -- Z축이 앞쪽이므로 -forward
	local moveDirectionWorld = mechPrimaryPart.CFrame.RightVector * moveDirectionRelative.X + mechPrimaryPart.CFrame.LookVector * moveDirectionRelative.Z
	
	local targetVelocity = Vector3.new(moveDirectionWorld.X, 0, moveDirectionWorld.Z) -- Y축 속도는 점프/중력으로 처리
	if targetVelocity.Magnitude > 0 then
		targetVelocity = targetVelocity.Unit * MECH_MAX_SPEED
	end
	
	-- 점프 처리 (간단한 예: 위로 힘 가하기 - 더 나은 방식은 Humanoid.JumpPower 또는 직접 힘 계산)
	if jumpInput and mechPrimaryPart.AssemblyLinearVelocity.Y < 1 then -- 땅에 있거나 떨어지고 있을 때만 점프 (간단한 체크)
		-- 이 방식은 한 번만 힘을 주므로, 지속적인 부양에는 다른 방식 필요
		mechPrimaryPart:ApplyImpulse(Vector3.new(0, 200 * mechPrimaryPart:GetMass(), 0)) -- 질량에 비례한 힘
		print(player.Name .. " 점프 입력 감지")
	end

	-- 부스트 처리 (간단한 예: 현재 이동 방향으로 추가 속도)
	if boostInput then
		targetVelocity = targetVelocity * 1.5 -- 예시: 속도 1.5배 증가
		print(player.Name .. " 부스트 입력 감지")
	end
	
	-- 2. 목표 각속도 계산 (Y축 회전)
	-- yawInput은 프레임당 회전량이므로, 이를 목표 각속도로 변환하려면 조절 필요
	-- 여기서는 단순하게 yawInput의 부호에 따라 최대 회전 속도를 설정
	local targetAngularVelocityY = 0
	if yawInput > 0.001 then -- 우회전
		targetAngularVelocityY = -MECH_MAX_TURN_SPEED
	elseif yawInput < -0.001 then -- 좌회전
		targetAngularVelocityY = MECH_MAX_TURN_SPEED
	end
	local targetAngularVelocity = Vector3.new(0, targetAngularVelocityY, 0)


	-- activeRobotPhysics 테이블에 목표치 저장 (선택 사항: RunService.Heartbeat에서 일괄 적용 위함)
	if not activeRobotPhysics[player] then activeRobotPhysics[player] = {} end
	activeRobotPhysics[player].Model = mechModel
	activeRobotPhysics[player].PrimaryPart = mechPrimaryPart
	activeRobotPhysics[player].TargetVelocity = targetVelocity
	activeRobotPhysics[player].TargetAngularVelocity = targetAngularVelocity
	
	-- 즉시 적용 방식 (Heartbeat 루프를 사용하지 않을 경우)
	-- mechPrimaryPart.AssemblyLinearVelocity = Vector3.new(targetVelocity.X, mechPrimaryPart.AssemblyLinearVelocity.Y, targetVelocity.Z) -- Y축 속도는 중력 등에 맡김
	-- mechPrimaryPart.AssemblyAngularVelocity = targetAngularVelocity
end

MechControlEvent.OnServerEvent:Connect(onMechControlReceived)

-- 선택 사항: 물리 업데이트 루프 (RunService.Heartbeat 사용)
-- 이 방식을 사용하면 모든 로봇의 물리 업데이트를 중앙에서 일관되게 처리 가능
RunService.Heartbeat:Connect(function(deltaTime: number)
	for player, physicsData in pairs(activeRobotPhysics) do
		if physicsData.PrimaryPart and physicsData.PrimaryPart.Parent then
			local currentLinVel = physicsData.PrimaryPart.AssemblyLinearVelocity
			local currentAngVel = physicsData.PrimaryPart.AssemblyAngularVelocity

			-- 목표 속도로 점진적으로 변경 (Lerp 사용 등) 또는 직접 설정
			-- 여기서는 Y축 속도는 유지하며 X, Z만 목표치로 설정
			physicsData.PrimaryPart.AssemblyLinearVelocity = Vector3.new(
				physicsData.TargetVelocity.X,
				currentLinVel.Y, -- 현재 Y축 속도 유지 (중력 적용되도록)
				physicsData.TargetVelocity.Z
			)
			physicsData.PrimaryPart.AssemblyAngularVelocity = physicsData.TargetAngularVelocity
		else
			-- PrimaryPart가 없거나 파괴된 경우 테이블에서 제거
			activeRobotPhysics[player] = nil
		end
	end
end)

print("[RobotMovementServer] 탑승형 로봇 움직임 처리 서버 스크립트 로드됨.")


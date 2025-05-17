-- 위치: ServerScriptService > ServerScripts > RobotMovementServer.server.lua
-- 기능: 클라이언트로부터 로봇 이동 이벤트를 받아 실제 로봇을 움직입니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local robotMoveEvent = ReplicatedStorage:WaitForChild("RobotMoveEvent")

local MOVE_SPEED = 20 -- 로봇 이동 속도
local ROTATION_SPEED = 5 -- 로봇 회전 속도 (여기서는 직접 회전 대신 카메라 기준 이동)

-- 플레이어의 로봇을 찾는 함수 (임시 - 실제 게임에서는 더 견고한 방법 필요)
local function getPlayerRobot(player)
	-- 이 예제에서는 Workspace에 "PlayerRobot"이라는 이름의 모델이 있고,
	-- 해당 모델이 플레이어의 캐릭터 역할을 한다고 가정합니다.
	-- 실제로는 플레이어 캐릭터에 로봇을 장착하거나, 플레이어별로 고유 ID를 가진 로봇을 찾아야 합니다.
	local character = player.Character
	if character then
		local robot = character:FindFirstChild("PlayerRobot") -- 플레이어 캐릭터의 자식으로 로봇이 있다고 가정
		if robot and robot:IsA("Model") and robot.PrimaryPart then
			return robot
		end
		-- 또는 Workspace에서 직접 찾기 (테스트용)
		-- 이 방식은 여러 플레이어가 있을 때 문제가 됩니다.
		return game.Workspace:FindFirstChild("PlayerRobot")
	end
	return nil
end


local function onRobotMove(player, direction)
	local robotModel = getPlayerRobot(player)
	if not robotModel or not robotModel.PrimaryPart then
		-- print("플레이어 " .. player.Name .. "의 로봇을 찾을 수 없습니다.")
		return
	end

	local robotPrimaryPart = robotModel.PrimaryPart

	if direction.Magnitude > 0 then
		-- 로봇의 현재 CFrame을 기준으로 이동 방향을 월드 좌표계로 변환
		-- 좀 더 나은 방식: 카메라 방향을 기준으로 이동 방향을 계산
		-- 여기서는 단순화를 위해 월드 축 기준으로 이동
		
		-- 캐릭터의 HumanoidRootPart를 기준으로 카메라 방향을 가져오기 시도
		local humanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local moveVectorWorld
		
		if humanoidRootPart then
			-- 카메라의 방향을 고려한 이동 (카메라가 바라보는 방향으로 전진)
			local cameraDirection = humanoidRootPart.CFrame.LookVector
			local rightDirection = humanoidRootPart.CFrame.RightVector
			
			moveVectorWorld = (cameraDirection * -direction.Z) + (rightDirection * direction.X)
			moveVectorWorld = Vector3.new(moveVectorWorld.X, 0, moveVectorWorld.Z).Unit -- Y축 이동은 무시하고 정규화
		else
			-- HumanoidRootPart가 없으면 월드 축 기준으로 이동 (단순 테스트용)
			moveVectorWorld = direction.Unit 
		end

		-- 이동 적용 (CFrame 직접 조작 - 물리 시뮬레이션과 충돌할 수 있으므로 BodyVelocity/AlignPosition 등이 더 좋음)
		robotPrimaryPart.CFrame = robotPrimaryPart.CFrame + moveVectorWorld * MOVE_SPEED * (1/60) -- 60FPS 기준

		-- 로봇이 이동 방향을 바라보도록 회전 (선택 사항)
		if moveVectorWorld.Magnitude > 0.01 then -- 아주 작은 움직임은 무시
			local targetCFrame = CFrame.new(robotPrimaryPart.Position, robotPrimaryPart.Position + moveVectorWorld)
			robotPrimaryPart.CFrame = robotPrimaryPart.CFrame:Lerp(targetCFrame, 0.1) -- 부드러운 회전
		end

	else
		-- 이동 방향이 0이면 (멈춤 신호), 로봇의 현재 속도를 0으로 설정할 수 있습니다.
		-- BodyVelocity를 사용한다면 velocity를 Vector3.new(0,0,0)으로 설정.
		-- 이 예제에서는 CFrame을 직접 조작하므로 별도 처리 불필요.
	end
end

robotMoveEvent.OnServerEvent:Connect(onRobotMove)

-- 플레이어가 접속했을 때 로봇을 스폰하고 연결하는 로직 (향후 구현)
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- 여기에 플레이어 캐릭터가 스폰될 때 로봇을 생성하거나 할당하는 로직 추가
		-- 예: Workspace의 "PlayerRobot"을 복제하여 캐릭터에 용접
		print(player.Name .. "의 캐릭터가 스폰되었습니다. 로봇 할당 로직 필요.")
		
		-- 임시: Workspace에 있는 PlayerRobot을 이 플레이어의 것으로 간주 (단일 플레이어 테스트용)
		-- 실제로는 각 플레이어마다 고유한 로봇 인스턴스를 관리해야 합니다.
		local testRobot = game.Workspace:FindFirstChild("PlayerRobot")
		if testRobot then
			-- testRobot.Name = player.Name .. "sRobot" -- 예시: 이름 변경
			-- testRobot:SetPrimaryPartCFrame(character:GetPrimaryPartCFrame() + Vector3.new(0, 5, 0)) -- 캐릭터 근처로 이동
		end
	end)
end)


print("로봇 이동 서버 스크립트 로드됨")


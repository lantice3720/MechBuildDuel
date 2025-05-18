--!strict
-- 플레이어 캐릭터 스폰 시 로봇을 생성하고, 플레이어를 해당 로봇의 좌석에 탑승

export type PlayerMechHandler = {
	initialize: () -> (),
}

local PlayerMechHandler: PlayerMechHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MechBuilder = require(ServerScriptService.Server.MechBuilder)
local PilotingStateChangedEvent: RemoteEvent = ReplicatedStorage:WaitForChild("PilotingStateChangedEvent")

-- 플레이어별 현재 탑승 중인 로봇(의 Seat) 또는 로봇 모델 추적
local playerPilotingMech: {[Player]: Seat | Model} = {} 

local function spawnAndPilotMech(player: Player, character: Model)
	-- 이미 플레이어가 다른 로봇에 탑승 중이거나, 관련 로봇이 있다면 추가 생성 방지 (필요시 더 정교한 로직)
	if playerPilotingMech[player] then
		-- 만약 Seat를 저장했다면, Seat의 부모(로봇 모델)가 아직 존재하는지 확인할 수 있음
		local existingSeatOrMech = playerPilotingMech[player]
		if (existingSeatOrMech:IsA("Seat") and existingSeatOrMech.Parent and existingSeatOrMech.Parent.Parent) or 
		   (existingSeatOrMech:IsA("Model") and existingSeatOrMech.Parent) then
			print(string.format("[PlayerMechHandler] %s는 이미 로봇에 탑승 중이거나 로봇이 할당되어 있습니다.", player.Name))
			-- 플레이어가 좌석에 앉아있는지 확인하고, 아니라면 다시 앉히는 로직도 추가 가능
			if character and character:FindFirstChildOfClass("Humanoid") and not character.Humanoid.Sit then
				local seat = existingSeatOrMech:IsA("Seat") and existingSeatOrMech or existingSeatOrMech:FindFirstChild("CockpitSeat")
				if seat and seat:IsA("Seat") then
					seat:Sit(character.Humanoid)
					PilotingStateChangedEvent:FireClient(player, true)
				end
			end
			return
		else
			print("유효하지 않은 playerPilotMech")
			playerPilotingMech[player] = nil -- 유효하지 않은 참조 제거
		end
	end

	print(string.format("[PlayerMechHandler] %s를 위한 새 탑승형 로봇 생성 시도.", player.Name))

	local mechModel = MechBuilder.createMechModel(player.Name .. "sMech")
	if not mechModel then
		warn(string.format("[PlayerMechHandler] %s를 위한 로봇 모델 생성 실패!", player.Name))
		return
	end

	mechModel.Parent = game.Workspace -- Workspace에 로봇 배치

	local cockpitSeat: Seat = mechModel:FindFirstChild("CockpitSeat", true) -- 로봇 모델 내의 좌석 찾기 (하위 객체까지 검색)
	if not cockpitSeat then
		warn(string.format("[PlayerMechHandler] %s에서 CockpitSeat를 찾을 수 없습니다! 로봇 파괴.", mechModel.Name))
		mechModel:Destroy()
		return
	end

	-- 로봇의 초기 위치 설정 (플레이어 스폰 위치 근처)
	local spawnLocationCFrame: CFrame
	if character and character.PrimaryPart then
		spawnLocationCFrame = character.PrimaryPart.CFrame
	else
		local spawns = game.Workspace:FindFirstChildOfClass("SpawnLocation")
		if spawns then
			spawnLocationCFrame = spawns.CFrame
		else
			spawnLocationCFrame = CFrame.new(0, 5, 0) 
		end
	end
	-- 로봇의 PrimaryPart(Torso)를 기준으로 위치를 설정합니다.
	mechModel:PivotTo(spawnLocationCFrame * CFrame.new(0, mechModel.PrimaryPart.Size.Y / 2 + 2, 5)) -- 플레이어 앞에 스폰 (거리 조절)
	
	-- 플레이어 캐릭터의 Humanoid가 로봇의 좌석에 탑승하도록 합니다.
	local humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false -- 혹시 앉아있던 상태라면 강제로 일으킴 (선택 사항)
		task.wait(0.1) -- Humanoid 상태 변경을 위한 짧은 지연
		cockpitSeat:Sit(humanoid)
		playerPilotingMech[player] = cockpitSeat -- 현재 탑승한 좌석을 기록

		PilotingStateChangedEvent:FireClient(player, true)
		print(string.format("[PlayerMechHandler] %s가 %s의 %s에 탑승 완료.", player.Name, mechModel.Name, cockpitSeat.Name))
	else
		warn(string.format("[PlayerMechHandler] %s의 캐릭터에서 Humanoid를 찾을 수 없어 탑승시키지 못했습니다.", player.Name))
		mechModel:Destroy() -- 로봇도 의미 없으므로 파괴
		return
	end

	-- 로봇(모델)이 파괴될 때 playerPilotingMech 테이블에서 제거하고 플레이어 강제 하차
	mechModel.Destroying:Connect(function()
		print(string.format("[PlayerMechHandler] 로봇 %s 파괴됨. %s 하차 처리 시도.", mechModel.Name, player.Name))
		if playerPilotingMech[player] == cockpitSeat then
			playerPilotingMech[player] = nil
			if humanoid and humanoid.Sit and humanoid.SeatPart == cockpitSeat then
				humanoid.Sit = false -- 플레이어 강제 하차

				PilotingStateChangedEvent:FireClient(player, false)
				print(string.format("[PlayerMechHandler] %s 하차 완료. 클라이언트에 알림.", player.Name))
			end
		end
		-- 여기서 플레이어에게 알림을 주거나, 리스폰 로직 등을 추가할 수 있습니다.
	end)

	-- 플레이어가 좌석에서 일어설 때 (예: '점프' 키로 하차) 처리
	humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
		if not humanoid.Sit and playerPilotingMech[player] == cockpitSeat then -- 앉아있지 않고, 현재 이 좌석에 탑승 중이었다면
			print(string.format("[PlayerMechHandler] %s가 %s에서 자발적으로 하차함.", player.Name, cockpitSeat.Name))
			playerPilotingMech[player] = nil
			-- 클라이언트에게 탑승 종료 알림 (false: 탑승 종료)
			PilotingStateChangedEvent:FireClient(player, false)
		end
	end)
end

local function onPlayerAdded(player: Player)
	print(string.format("[PlayerMechHandler] %s 플레이어 접속.", player.Name))
	player.CharacterAdded:Connect(function(character: Model)
		-- CharacterAdded는 캐릭터 모델이 Workspace에 추가될 때 발생합니다.
		-- 플레이어의 Humanoid가 준비될 때까지 잠시 기다리는 것이 안전할 수 있습니다.
		character:WaitForChild("Humanoid", 5) -- Humanoid가 로드될 때까지 최대 5초 대기
		if not character:FindFirstChildOfClass("Humanoid") then return end -- Humanoid 없으면 진행 불가

		-- 캐릭터가 완전히 로드된 후 로봇 스폰 및 탑승 로직 실행
		-- task.defer(spawnAndPilotMech, player, character) -- 다음 프레임에 실행하여 안정성 확보
		spawnAndPilotMech(player, character)
	end)
end

function PlayerMechHandler.initialize()
	print("[PlayerMechHandler] 로드됨.")
	Players.PlayerAdded:Connect(onPlayerAdded)
end


return PlayerMechHandler

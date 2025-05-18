-- 플레이어가 탑승할 로봇 기체의 모델을 생성하고 반환합니다.

export type MechBuilder = {
	createMechModel: (name: string) -> Model
}

local MechBuilder: MechBuilder = {}

-- (DamageHandler 관련 부분은 이전과 동일하게 유지하거나 필요에 따라 수정)
local DamageHandler -- : ModuleScript? 
local function handlePartClick(playerWhoClicked: Player, partClicked: BasePart)
	if DamageHandler then
		DamageHandler.processPartDamage(partClicked, 10, playerWhoClicked)
	else
		local currentHealth = partClicked:GetAttribute("Health")
		if typeof(currentHealth) == "number" then
			currentHealth -= 10
			partClicked:SetAttribute("Health", currentHealth)
			print(string.format("[MechBuilder-ClickDebug] %s가 %s 클릭. 새 체력: %d", playerWhoClicked.Name, partClicked.Name, currentHealth))
			if currentHealth <= 0 then
				partClicked.Transparency = 0.8
				partClicked.Color = Color3.fromRGB(20,20,20)
				print(partClicked.Name .. " 파괴됨 (임시)")
			end
		end
	end
end

function MechBuilder.createMechModel(name: string): Model
	local mechModel = Instance.new("Model")
	mechModel.Name = name

	-- 1. 주요 파트 생성
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(6, 7, 3)
	torso.Color = Color3.fromRGB(120, 120, 120)
	torso.Anchored = false -- 로봇은 움직여야 하므로 Anchor 해제
	torso.CanCollide = true
	torso.Parent = mechModel
	mechModel.PrimaryPart = torso

	local head = Instance.new("Part")
	head.Name = "Head"
	-- ... (머리, 팔, 다리 파트 생성 및 속성 설정은 이전과 유사하게 유지) ...
	head.Size = Vector3.new(3, 3, 3); head.Color = Color3.fromRGB(100,100,100); head.Anchored = false; head.CanCollide = true
	head.Position = torso.Position + Vector3.new(0, torso.Size.Y/2 + head.Size.Y/2, 0); head.Parent = mechModel

	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"; leftArm.Size = Vector3.new(2, 6, 2); leftArm.Color = Color3.fromRGB(100,100,100); leftArm.Anchored = false; leftArm.CanCollide = true
	leftArm.Position = torso.Position + Vector3.new(-torso.Size.X/2 - leftArm.Size.X/2, 0, 0); leftArm.Parent = mechModel

	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"; rightArm.Size = Vector3.new(2, 6, 2); rightArm.Color = Color3.fromRGB(100,100,100); rightArm.Anchored = false; rightArm.CanCollide = true
	rightArm.Position = torso.Position + Vector3.new(torso.Size.X/2 + rightArm.Size.X/2, 0, 0); rightArm.Parent = mechModel
	
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "LeftLeg"; leftLeg.Size = Vector3.new(2.5, 7, 2.5); leftLeg.Color = Color3.fromRGB(100,100,100); leftLeg.Anchored = false; leftLeg.CanCollide = true
	leftLeg.Position = torso.Position + Vector3.new(-torso.Size.X/4, -torso.Size.Y/2 - leftLeg.Size.Y/2, 0); leftLeg.Parent = mechModel

	local rightLeg = Instance.new("Part")
	rightLeg.Name = "RightLeg"; rightLeg.Size = Vector3.new(2.5, 7, 2.5); rightLeg.Color = Color3.fromRGB(100,100,100); rightLeg.Anchored = false; rightLeg.CanCollide = true
	rightLeg.Position = torso.Position + Vector3.new(torso.Size.X/4, -torso.Size.Y/2 - rightLeg.Size.Y/2, 0); rightLeg.Parent = mechModel

	-- 2. 파일럿 좌석(Seat) 생성 및 배치
	local cockpitSeat = Instance.new("Seat")
	cockpitSeat.Name = "CockpitSeat"
	cockpitSeat.Size = Vector3.new(2, 2, 2) -- 좌석 크기
	cockpitSeat.Color = Color3.fromRGB(50, 50, 50) -- 어두운 색
	cockpitSeat.Anchored = false -- 몸통에 용접될 것이므로 false
	cockpitSeat.CanCollide = false -- 플레이어가 통과하여 앉을 수 있도록 (선택 사항)
	-- 좌석 위치: 몸통(Torso)의 약간 앞쪽 중앙에 배치 (예시)
	cockpitSeat.Position = torso.Position + Vector3.new(0, torso.Size.Y/4, torso.Size.Z/2 - cockpitSeat.Size.Z/2 + 0.5) 
	cockpitSeat.Orientation = torso.Orientation -- 몸통과 같은 방향을 보도록
	cockpitSeat.Parent = mechModel

	-- 3. 파트 용접 (좌석 포함)
	local partsToWeld = {head, leftArm, rightArm, leftLeg, rightLeg, cockpitSeat}
	for _, partToWeld:Instance in ipairs(partsToWeld) do
		if partToWeld:IsA("BasePart") or partToWeld:IsA("Seat") then -- Seat도 BasePart를 상속합니다.
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = partToWeld
			weld.Parent = torso 
		end
	end
	
	-- 4. Humanoid 제거! (로봇 자체는 Humanoid를 갖지 않음)
	-- 이전에 Humanoid를 추가하는 코드가 있었다면 삭제합니다.

	-- 5. 각 부위에 Health Attribute 및 ClickDetector 추가 (이전과 동일)
	local damageableParts = {torso, head, leftArm, rightArm, leftLeg, rightLeg} -- 좌석은 데미지 입지 않도록 제외 (선택)
	for _, part:BasePart in ipairs(damageableParts) do
		part:SetAttribute("Health", 100) 

		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 64 
		clickDetector.Parent = part

		clickDetector.MouseClick:Connect(function(playerWhoClicked: Player)
			-- 중요: 이제 playerWhoClicked가 이 로봇에 탑승한 플레이어인지 확인하는 로직이 필요할 수 있음
			-- (예: 자신의 로봇 부품을 실수로 클릭하여 데미지 입는 것을 방지)
			-- 지금은 테스트를 위해 모든 클릭에 반응하도록 둡니다.
			handlePartClick(playerWhoClicked, part)
		end)
		-- print(string.format("[MechBuilder] %s 파트에 ClickDetector 및 Health Attribute 설정 완료.", part.Name)) -- 로그는 필요시 유지
	end
	
	print(string.format("[MechBuilder] 탑승형 로봇 %s 모델 생성 완료.", mechModel.Name))
	return mechModel
end

return MechBuilder

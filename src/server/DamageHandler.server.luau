-- 위치: src/server/DamageHandler.server.lua
-- 기능: 로봇 부위의 데미지 및 파괴를 중앙에서 처리합니다.

local function processPartDamage(partInstance: DataModel, damageAmount: number, instigatorPlayer: Player?)
	if not partInstance or not partInstance:IsA("BasePart") then
		warn("[DamageHandler] 유효하지 않은 파트가 전달되었습니다:", partInstance)
		return
	end

	local currentHealth = partInstance:GetAttribute("Health")

	if currentHealth == nil then
		-- Health Attribute가 없는 파트는 데미지 처리하지 않음 (또는 기본값 설정 후 처리)
		-- print("[DamageHandler] 파트 '" .. partInstance:GetFullName() .. "'에 Health 속성이 없어 데미지 처리를 건너뜁니다.")
		return
	end

	if typeof(currentHealth) ~= "number" then
		warn("[DamageHandler] 파트 '" .. partInstance:GetFullName() .. "'의 Health 속성이 숫자가 아닙니다.")
		return
	end	

	local instigatorName = instigatorPlayer and instigatorPlayer.Name or "알 수 없음"
	print(string.format("[DamageHandler] %s가 %s 부위(%s)에 %d 데미지를 입히려 합니다. 현재 체력: %d",
		instigatorName, partInstance.Name, partInstance:GetFullName(), damageAmount, currentHealth))

	currentHealth = currentHealth - damageAmount
	partInstance:SetAttribute("Health", currentHealth)

	print(string.format("[DamageHandler] %s 부위 체력: %d", partInstance.Name, currentHealth))

	if currentHealth <= 0 then
		print("[DamageHandler] " .. partInstance.Name .. " 부위가 파괴되었습니다!")
		partInstance.Transparency = 0.8
		partInstance.Color = Color3.fromRGB(30, 30, 30)
		
		local clickDetector = partInstance:FindFirstChildOfClass("ClickDetector")
		if clickDetector then
			-- clickDetector.MaxActivationDistance = 0 -- 더 이상 클릭 안 되게
		end
		-- TODO: 실제 파괴 효과 (기능 정지, 파트 분리 등) 로직 추가
	end
end

-- 게임 내 모든 ClickDetector의 클릭 이벤트를 감지하여 데미지 처리기에 연결
-- 이 방식은 매우 일반적이므로, 특정 로봇 파트에만 적용되도록 조건을 추가해야 할 수 있습니다.
local function setupClickDetectorsRecursive(instance: Workspace)
	if instance:IsA("ClickDetector") then
		-- 이 ClickDetector가 로봇의 부품에 속하는지 확인하는 로직이 필요할 수 있습니다.
		-- 예를 들어, 부모나 상위 모델의 이름이 "PlayerRobot"인지 등으로 구분합니다.
		local part = instance.Parent
		if part and part:IsA("BasePart") and part:GetAttribute("Health") ~= nil then -- Health Attribute가 있는 파트의 ClickDetector만 처리
			print("[DamageHandler] " .. part:GetFullName() .. " 내 ClickDetector에 이벤트 연결 시도.")
			instance.MouseClick:Connect(function(playerWhoClicked)
				processPartDamage(part, 10, playerWhoClicked) -- 클릭 시 10 데미지
			end)
		end
	end

	for _, child in ipairs(instance:GetChildren()) do
		setupClickDetectorsRecursive(child)
	end
end

-- Workspace에 있는 모든 객체에 대해 ClickDetector 설정 (게임 시작 시 한 번 실행)
-- 실제로는 로봇이 스폰될 때 해당 로봇에 대해서만 이 설정을 해주는 것이 더 효율적입니다.
-- 지금은 테스트를 위해 Workspace 전체를 대상으로 합니다.
setupClickDetectorsRecursive(game.Workspace)
-- 또는 특정 모델에 대해서만 실행
-- local robotModel = game.Workspace:FindFirstChild("PlayerRobot")
-- if robotModel then
--  setupClickDetectorsRecursive(robotModel)
-- end


print("[DamageHandler] 데미지 핸들러 스크립트 로드됨.")

-- 초기 로봇 파트 체력 설정 안내용 로그 (실제 게임에서는 로봇 스폰 시점에 적용)
-- 이 부분은 DamageHandler의 역할이라기보다는 로봇 초기화 로직에 가깝습니다.
-- 지금은 테스트를 위해 Workspace의 PlayerRobot 모델을 찾아 체력 설정 여부만 확인합니다.
local function checkInitialHealth()
	local robotModel = game.Workspace:FindFirstChild("MechOne")
	if robotModel then
		for _, partInstance in ipairs(robotModel:GetDescendants()) do
			if partInstance:IsA("BasePart") then
				local health = partInstance:GetAttribute("Health")
				if health ~= nil then
					print(string.format("[DamageHandler_InitCheck] %s 부위 초기 체력: %s", partInstance:GetFullName(), tostring(health)))
				else
					print(string.format("[DamageHandler_InitCheck] %s 부위 초기 체력: 설정 안됨", partInstance:GetFullName()))
				end
			end
		end
	else
		print("[DamageHandler_InitCheck] PlayerRobot 모델을 Workspace에서 찾을 수 없습니다.")
	end
end

checkInitialHealth() -- 필요하다면 게임 시작 시 한 번 호출
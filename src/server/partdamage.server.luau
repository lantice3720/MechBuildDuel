-- 위치: "PlayerRobot" 모델 내의 각 주요 파트(예: RightArm) 안에 Script로 추가
-- 기능: 이 스크립트가 포함된 파트를 클릭하면 해당 파트의 'Health' 속성을 감소시킵니다.

local part = script.Parent -- 이 스크립트가 들어있는 파트
local clickDetector = part:FindFirstChildOfClass("ClickDetector")

-- 클릭 디텍터가 없다면 생성
if not clickDetector then
	clickDetector = Instance.new("ClickDetector")
	clickDetector.Parent = part
end

local DAMAGE_AMOUNT = 10 -- 클릭당 데미지

local function onPartClicked(playerWhoClicked)
	local currentHealth = part:GetAttribute("Health")

	if currentHealth == nil then
		warn("경고: 파트 '" .. part.Name .. "'에 Health 속성이 없습니다.")
		part:SetAttribute("Health", 100) -- 임시로 생성
		currentHealth = 100
	end

	if typeof(currentHealth) ~= "number" then
		warn("경고: 파트 '" .. part.Name .. "'의 Health 속성이 숫자가 아닙니다.")
		return
	end

	print(playerWhoClicked.Name .. "님이 " .. part.Name .. "을(를) 클릭했습니다. 현재 체력: " .. currentHealth)

	currentHealth = currentHealth - DAMAGE_AMOUNT
	part:SetAttribute("Health", currentHealth)

	print(part.Name .. "의 체력이 " .. DAMAGE_AMOUNT .. "만큼 감소하여 " .. currentHealth .. "이(가) 되었습니다.")

	-- 체력이 0 이하가 되면 파괴 처리 (간단한 시각적 효과)
	if currentHealth <= 0 then
		print(part.Name .. "이(가) 파괴되었습니다!")
		part.Transparency = 0.7
		part.Color = Color3.fromRGB(50, 50, 50) -- 어두운 색으로 변경
		-- clickDetector:Destroy() -- 더 이상 클릭되지 않도록 제거 (선택 사항)

		-- TODO: 실제 파괴 효과 (파트 분리, 폭발 등) 추가
		-- TODO: 로봇 전체의 파괴 판정 로직 연결
	end
end

clickDetector.MouseClick:Connect(onPartClicked)

print(part.Name .. "에 데미지 테스트 스크립트 적용됨. 초기 체력: " .. (part:GetAttribute("Health") or "설정 안됨"))


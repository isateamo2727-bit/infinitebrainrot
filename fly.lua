-- == Fly Executor Script (BodyVelocity ou CFrame) ==
-- Use em executor. Testado logicamente — adapte valores conforme o jogo.
-- Linguagem: Lua (Roblox)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:FindFirstChildOfClass("Humanoid")

-- Config (ajuste como quiser)
local ascendSpeed = 60
local descendSpeed = 60
local moveSpeed = 40
local smoothing = 8            -- quanto maior, mais suave (lerp)
local bodyForceBase = 4000    -- base para MaxForce (multiplica se carregar item)
local cframeLerpAlpha = 0.25  -- para modo CFrame: quão rápido o CFrame interpola (0-1)

-- Estado
local flying = false
local method = "BodyVelocity" -- "BodyVelocity" or "CFrame"
local bv -- BodyVelocity instance
local lastVelocity = Vector3.new()
local heldObjectMultiplier = 1

-- UI simples
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game.CoreGui

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 220, 0, 120)
Frame.Position = UDim2.new(0.03,0,0.15,0)
Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
Frame.BorderSizePixel = 0
Frame.Active = true

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1,0,0,24)
Title.BackgroundTransparency = 1
Title.Text = "Executor Fly"
Title.TextColor3 = Color3.new(1,1,1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 14

local ToggleBtn = Instance.new("TextButton", Frame)
ToggleBtn.Size = UDim2.new(0.48, -6, 0, 36)
ToggleBtn.Position = UDim2.new(0, 6, 0, 30)
ToggleBtn.Text = "Ativar Fly"
ToggleBtn.TextColor3 = Color3.new(1,1,1)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)

local MethodBtn = Instance.new("TextButton", Frame)
MethodBtn.Size = UDim2.new(0.48, -6, 0, 36)
MethodBtn.Position = UDim2.new(0.52, 0, 0, 30)
MethodBtn.Text = "Método: BodyVel"
MethodBtn.TextColor3 = Color3.new(1,1,1)
MethodBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)

local Info = Instance.new("TextLabel", Frame)
Info.Size = UDim2.new(1,0,0,40)
Info.Position = UDim2.new(0,0,0,72)
Info.BackgroundTransparency = 1
Info.TextColor3 = Color3.fromRGB(200,200,200)
Info.Font = Enum.Font.SourceSans
Info.TextSize = 12
Info.Text = "Space: subir • Shift: descer • WASD: mover"

-- Função utilitária: detecta se o player está segurando objeto / tem tool acessório que pode atrapalhar
local function checkHoldingThing()
	-- verifica ferramentas na mão
	if player.Character then
		for _, child in ipairs(player.Character:GetChildren()) do
			if child:IsA("Tool") and child.Parent == player.Character then
				return true
			end
		end
		-- verifica Attachments/Accessories — heurística simples
		for _, acc in ipairs(player.Character:GetChildren()) do
			if acc:IsA("Accessory") then
				-- se accessory tem Handle e não está welded corretamente pode influenciar
				local h = acc:FindFirstChild("Handle")
				if h then
					-- se handle tem massa maior que um threshold
					if h:GetMass() > 1 then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Cria BodyVelocity (deixa pronto; só parenta quando necessário)
local function ensureBV()
	if not bv or not bv.Parent then
		bv = Instance.new("BodyVelocity")
		bv.Name = "ExecutorFly_BodyVelocity"
		bv.MaxForce = Vector3.new(0,0,0)
		bv.Velocity = Vector3.new(0,0,0)
		bv.Parent = hrp
	end
end

-- Calcula direção de movimento baseado na camera e teclas
local function getMoveDirection()
	local cam = workspace.CurrentCamera
	local dir = Vector3.new()
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude > 0 then dir = dir.Unit end
	return dir
end

-- Aplica física via BodyVelocity (mais "aceito" pelo motor)
local function applyBodyVelocity(dt)
	ensureBV()
	-- adapta se carregando item (aumenta força)
	heldObjectMultiplier = checkHoldingThing() and 2 or 1
	local maxForceVal = bodyForceBase * heldObjectMultiplier
	bv.MaxForce = Vector3.new(maxForceVal, maxForceVal, maxForceVal)

	local moveDir = getMoveDirection()
	local yVel = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		yVel = ascendSpeed
	elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		yVel = -descendSpeed
	end

	local targetVel = Vector3.new(moveDir.X * moveSpeed, yVel, moveDir.Z * moveSpeed)
	-- suaviza para evitar mudanças abruptas (reduz rollback/flags)
	local cur = bv.Velocity
	local lerped = (cur * (1 - math.clamp(smoothing * dt,0,1))) + (targetVel * math.clamp(smoothing * dt,0,1))
	bv.Velocity = lerped
end

-- Aplica movimento via CFrame (mais "direto", possivelmente mais detectável)
local function applyCFrame(dt)
	-- calcula target posição incremental
	local dir = getMoveDirection()
	local y = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		y = ascendSpeed
	elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		y = -descendSpeed
	end

	-- construindo deslocamento baseado em dt para ficar consistente
	local displacement = Vector3.new(dir.X * moveSpeed * dt, y * dt, dir.Z * moveSpeed * dt)
	local targetCFrame = hrp.CFrame + displacement

	-- suaviza com Lerp
	local newCFrame = hrp.CFrame:Lerp(targetCFrame, math.clamp(cframeLerpAlpha, 0, 1))
	-- tenta preservar orientação da câmera (opcional)
	hrp.CFrame = newCFrame
end

-- Toggle fly
local function setFly(state)
	flying = state
	if flying then
		ToggleBtn.Text = "Desativar Fly"
		if method == "BodyVelocity" then
			ensureBV()
			bv.MaxForce = Vector3.new(0,0,0) -- será ajustado no loop
			bv.Velocity = Vector3.new(0,0,0)
		end
	else
		ToggleBtn.Text = "Ativar Fly"
		-- cleanup
		if bv and bv.Parent then
			bv.Velocity = Vector3.new(0,0,0)
			bv.MaxForce = Vector3.new(0,0,0)
			-- não destrói o bv para evitar reparent issues; mas poderia fazer bv:Destroy()
		end
	end
end

-- UI interactions
ToggleBtn.MouseButton1Click:Connect(function()
	setFly(not flying)
end)

MethodBtn.MouseButton1Click:Connect(function()
	if method == "BodyVelocity" then
		method = "CFrame"
		MethodBtn.Text = "Método: CFrame"
	else
		method = "BodyVelocity"
		MethodBtn.Text = "Método: BodyVel"
	end
end)

-- Main loop
local last = tick()
RunService.Heartbeat:Connect(function(step)
	-- garante referência atual do personagem se respawnar
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		char = player.Character or player.CharacterAdded:Wait()
		hrp = char:WaitForChild("HumanoidRootPart")
		-- reparent BV se existir
		if bv and bv.Parent ~= hrp then
			pcall(function() bv.Parent = hrp end)
		end
	end

	if not flying then return end

	-- se estiver voando, aplica por método
	if method == "BodyVelocity" then
		pcall(function() applyBodyVelocity(step) end)
	else
		pcall(function() applyCFrame(step) end)
	end
end)

-- inicializa (opcional)
setFly(false)

-- Fim do script

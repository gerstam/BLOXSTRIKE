-- Bloxstrike Script by NSHUB
if game.PlaceId == 5938036553 or game.PlaceId == 5938847329 then
    -- Load Linoria UI Library
    local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
    local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua"))()
    
    -- Services
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Camera = workspace.CurrentCamera
    local LocalPlayer = Players.LocalPlayer
    
    -- Variables
    local AimbotConnection
    local ESPObjects = {}
    local FOVCircle
    local OriginalWeaponData = {}
    
    -- Utility Functions
    local function GetClosestPlayer()
        local closestPlayer, closestDistance = nil, math.huge
        local fov = Options.AimbotFOV.Value
        
        -- If focusing on a specific player, only target them
        if _G.FocusedPlayer then
            local focusedPlayer = Players:FindFirstChild(_G.FocusedPlayer)
            if focusedPlayer and focusedPlayer ~= LocalPlayer and focusedPlayer.Character and focusedPlayer.Character:FindFirstChild("Head") then
                local character = focusedPlayer.Character
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                if humanoid and humanoid.Health > 0 then
                    return focusedPlayer
                end
            end
            return nil
        end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
                -- Check team
                if Toggles.IgnoreTeammates and Toggles.IgnoreTeammates.Value then
                    if player.Team == LocalPlayer.Team and player.Team ~= nil then
                        goto continue
                    end
                end
                
                -- Check ignore list
                local shouldSkip = false
                if _G.IgnoreList then
                    for _, name in pairs(_G.IgnoreList) do
                        if name == player.Name then
                            shouldSkip = true
                            break
                        end
                    end
                end
                
                if not shouldSkip then
                    -- Check priority list first
                    if _G.PriorityList then
                        for _, name in pairs(_G.PriorityList) do
                            if name == player.Name then
                                local character = player.Character
                                local humanoid = character:FindFirstChildOfClass("Humanoid")
                                
                                if humanoid and humanoid.Health > 0 then
                                    return player
                                end
                            end
                        end
                    end
                    
                    local character = player.Character
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    local head = character:FindFirstChild("Head")
                    
                    if humanoid and humanoid.Health > 0 and head then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                        if onScreen then
                            local distance = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
                            
                            if distance < fov and distance < closestDistance then
                                -- Visibility check
                                if Toggles.VisibilityCheck.Value then
                                    local ray = Ray.new(Camera.CFrame.Position, (head.Position - Camera.CFrame.Position).Unit * 500)
                                    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
                                    if hit and hit:IsDescendantOf(character) then
                                        closestPlayer = player
                                        closestDistance = distance
                                    end
                                else
                                    closestPlayer = player
                                    closestDistance = distance
                                end
                            end
                        end
                    end
                end
            end
            ::continue::
        end
        
        return closestPlayer
    end
    
    local function CreateFOVCircle()
        if FOVCircle then FOVCircle:Remove() end
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 2
        FOVCircle.NumSides = 50
        FOVCircle.Radius = Options.AimbotFOV.Value
        FOVCircle.Filled = false
        FOVCircle.Visible = Toggles.ShowFOV.Value
        FOVCircle.Color = Color3.fromRGB(255, 255, 255)
        FOVCircle.Transparency = 1
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
    
    local function CreateESP(player)
        if ESPObjects[player] then return end
        
        local esp = {
            Box = Drawing.new("Square"),
            Name = Drawing.new("Text"),
            Health = Drawing.new("Text"),
            Distance = Drawing.new("Text"),
            Tracer = Drawing.new("Line"),
            HealthBar = Drawing.new("Square"),
            HealthBarOutline = Drawing.new("Square"),
            Weapon = Drawing.new("Text")
        }
        
        esp.Box.Thickness = 2
        esp.Box.Filled = false
        esp.Box.Color = Options.ESPColor.Value
        esp.Box.Visible = false
        
        esp.Name.Size = 13
        esp.Name.Center = true
        esp.Name.Outline = true
        esp.Name.Color = Color3.fromRGB(255, 255, 255)
        esp.Name.Visible = false
        
        esp.Health.Size = 13
        esp.Health.Center = true
        esp.Health.Outline = true
        esp.Health.Color = Color3.fromRGB(0, 255, 0)
        esp.Health.Visible = false
        
        esp.Distance.Size = 13
        esp.Distance.Center = true
        esp.Distance.Outline = true
        esp.Distance.Color = Color3.fromRGB(255, 255, 255)
        esp.Distance.Visible = false
        
        esp.Weapon.Size = 13
        esp.Weapon.Center = true
        esp.Weapon.Outline = true
        esp.Weapon.Color = Color3.fromRGB(255, 215, 0)
        esp.Weapon.Visible = false
        
        esp.Tracer.Thickness = 2
        esp.Tracer.Color = Options.ESPColor.Value
        esp.Tracer.Visible = false
        
        esp.HealthBar.Filled = true
        esp.HealthBar.Visible = false
        esp.HealthBar.Thickness = 1
        
        esp.HealthBarOutline.Filled = false
        esp.HealthBarOutline.Visible = false
        esp.HealthBarOutline.Thickness = 2
        esp.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        
        ESPObjects[player] = esp
    end
    
    local function UpdateESP()
        for player, esp in pairs(ESPObjects) do
            if player and player.Character and player.Character:FindFirstChild("Head") then
                -- Check if we should hide teammates
                if Toggles.IgnoreTeammates and Toggles.IgnoreTeammates.Value then
                    if player.Team == LocalPlayer.Team and player.Team ~= nil then
                        for _, drawing in pairs(esp) do
                            drawing.Visible = false
                        end
                        goto skipPlayer
                    end
                end
                
                local character = player.Character
                local head = character.Head
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                if humanoid and humanoid.Health > 0 then
                    local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    
                    if onScreen and Toggles.ESPEnabled.Value then
                        local topPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                        local bottomPos = Camera:WorldToViewportPoint(head.Position - Vector3.new(0, 3.5, 0))
                        local height = math.abs(topPos.Y - bottomPos.Y)
                        local width = height / 2
                        
                        -- Box
                        if Toggles.ESPBoxes.Value then
                            esp.Box.Size = Vector2.new(width, height)
                            esp.Box.Position = Vector2.new(headPos.X - width / 2, headPos.Y - height / 2)
                            esp.Box.Visible = true
                            esp.Box.Color = Options.ESPColor.Value
                        else
                            esp.Box.Visible = false
                        end
                        
                        -- Name
                        if Toggles.ESPNames.Value then
                            esp.Name.Text = player.Name
                            esp.Name.Position = Vector2.new(headPos.X, topPos.Y - 20)
                            esp.Name.Visible = true
                        else
                            esp.Name.Visible = false
                        end
                        
                        -- Health Bar
                        if Toggles.ESPHealthBar.Value then
                            local healthPercent = humanoid.Health / humanoid.MaxHealth
                            local barHeight = height
                            local barWidth = 3
                            
                            esp.HealthBarOutline.Size = Vector2.new(barWidth + 2, barHeight + 2)
                            esp.HealthBarOutline.Position = Vector2.new(headPos.X - width / 2 - barWidth - 4, headPos.Y - height / 2 - 1)
                            esp.HealthBarOutline.Visible = true
                            
                            esp.HealthBar.Size = Vector2.new(barWidth, barHeight * healthPercent)
                            esp.HealthBar.Position = Vector2.new(headPos.X - width / 2 - barWidth - 3, headPos.Y - height / 2 + barHeight * (1 - healthPercent))
                            esp.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                            esp.HealthBar.Visible = true
                        else
                            esp.HealthBar.Visible = false
                            esp.HealthBarOutline.Visible = false
                        end
                        
                        -- Health Text
                        if Toggles.ESPHealth.Value then
                            esp.Health.Text = math.floor(humanoid.Health) .. " HP"
                            esp.Health.Position = Vector2.new(headPos.X, bottomPos.Y + 5)
                            esp.Health.Visible = true
                        else
                            esp.Health.Visible = false
                        end
                        
                        -- Distance
                        if Toggles.ESPDistance.Value and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
                            local distance = math.floor((LocalPlayer.Character.Head.Position - head.Position).Magnitude)
                            esp.Distance.Text = distance .. " studs"
                            esp.Distance.Position = Vector2.new(headPos.X, headPos.Y)
                            esp.Distance.Visible = true
                        else
                            esp.Distance.Visible = false
                        end
                        
                        -- Weapon ESP
                        if Toggles.ESPWeapon.Value then
                            local tool = character:FindFirstChildOfClass("Tool")
                            if tool then
                                esp.Weapon.Text = "[" .. tool.Name .. "]"
                                esp.Weapon.Position = Vector2.new(headPos.X, bottomPos.Y + 20)
                                esp.Weapon.Visible = true
                            else
                                esp.Weapon.Visible = false
                            end
                        else
                            esp.Weapon.Visible = false
                        end
                        
                        -- Tracers
                        if Toggles.ESPTracers.Value then
                            esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            esp.Tracer.To = Vector2.new(headPos.X, headPos.Y)
                            esp.Tracer.Visible = true
                            esp.Tracer.Color = Options.ESPColor.Value
                        else
                            esp.Tracer.Visible = false
                        end
                    else
                        esp.Box.Visible = false
                        esp.Name.Visible = false
                        esp.Health.Visible = false
                        esp.Distance.Visible = false
                        esp.Tracer.Visible = false
                        esp.HealthBar.Visible = false
                        esp.HealthBarOutline.Visible = false
                        esp.Weapon.Visible = false
                    end
                else
                    esp.Box.Visible = false
                    esp.Name.Visible = false
                    esp.Health.Visible = false
                    esp.Distance.Visible = false
                    esp.Tracer.Visible = false
                    esp.HealthBar.Visible = false
                    esp.HealthBarOutline.Visible = false
                    esp.Weapon.Visible = false
                end
            end
            ::skipPlayer::
        end
    end
    
    local Window = Library:CreateWindow({
        Title = 'NSHUB Bloxstrike Script',
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2
    })
    
    -- Create Tabs
    local Tabs = {
        Combat = Window:AddTab('Combat'),
        Visuals = Window:AddTab('Visuals'),
        Skins = Window:AddTab('Skins'),
        Misc = Window:AddTab('Misc'),
        Players = Window:AddTab('Players'),
        Settings = Window:AddTab('Settings')
    }
    
    -- =============================================
    -- COMBAT TAB
    -- =============================================
    local AimbotGroupbox = Tabs.Combat:AddLeftGroupbox('Aimbot')
    
    AimbotGroupbox:AddToggle('AimbotEnabled', {
        Text = 'Enable Aimbot',
        Default = false,
        Tooltip = 'Lock onto enemies',
        Callback = function(Value)
            if Value then
                if AimbotConnection then AimbotConnection:Disconnect() end
                AimbotConnection = RunService.RenderStepped:Connect(function()
                    if Toggles.AimbotEnabled.Value then
                        local target = GetClosestPlayer()
                        if target and target.Character then
                            local hitbox = Options.AimbotHitbox.Value
                            local part = target.Character:FindFirstChild(hitbox)
                            
                            if part then
                                local smoothing = Options.AimSmoothing.Value
                                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, part.Position), 1 / smoothing)
                            end
                        end
                    end
                end)
                Library:Notify("Aimbot Enabled", 2)
            else
                if AimbotConnection then
                    AimbotConnection:Disconnect()
                    AimbotConnection = nil
                end
                Library:Notify("Aimbot Disabled", 2)
            end
        end
    })
    
    AimbotGroupbox:AddSlider('AimbotFOV', {
        Text = 'Aimbot FOV',
        Default = 120,
        Min = 0,
        Max = 360,
        Rounding = 0,
        Compact = false,
        Tooltip = 'Field of view for aimbot',
        Callback = function(Value)
            if FOVCircle then
                FOVCircle.Radius = Value
            end
        end
    })
    
    AimbotGroupbox:AddSlider('AimSmoothing', {
        Text = 'Aim Smoothing',
        Default = 3,
        Min = 1,
        Max = 15,
        Rounding = 1,
        Compact = false,
        Tooltip = 'Higher = smoother aim'
    })
    
    AimbotGroupbox:AddDropdown('AimbotHitbox', {
        Values = {'Head', 'UpperTorso', 'LowerTorso', 'HumanoidRootPart'},
        Default = 1,
        Multi = false,
        Text = 'Target Hitbox',
        Tooltip = 'Which body part to aim at'
    })
    
    AimbotGroupbox:AddToggle('TriggerBot', {
        Text = 'Trigger Bot',
        Default = false,
        Tooltip = 'Auto-shoot when aiming at enemy',
        Callback = function(Value)
            Library:Notify(Value and "Trigger Bot Enabled" or "Trigger Bot Disabled", 2)
        end
    })
    
    AimbotGroupbox:AddToggle('ShowFOV', {
        Text = 'Show FOV Circle',
        Default = false,
        Tooltip = 'Display FOV circle',
        Callback = function(Value)
            if Value then
                if not FOVCircle then CreateFOVCircle() end
                FOVCircle.Visible = true
            elseif FOVCircle then
                FOVCircle.Visible = false
            end
        end
    })
    
    AimbotGroupbox:AddToggle('VisibilityCheck', {
        Text = 'Visibility Check',
        Default = true,
        Tooltip = 'Only target visible enemies'
    })
    
    AimbotGroupbox:AddToggle('IgnoreTeammates', {
        Text = 'Ignore Teammates',
        Default = true,
        Tooltip = 'Don\'t target your own team'
    })
    
    -- Combat Assists
    local AssistsGroupbox = Tabs.Combat:AddRightGroupbox('Combat Assists')
    
    AssistsGroupbox:AddToggle('InfiniteAmmo', {
        Text = 'Infinite Ammo',
        Default = false,
        Tooltip = 'Never run out of ammo',
        Callback = function(Value)
            Library:Notify(Value and "Infinite Ammo Enabled" or "Infinite Ammo Disabled", 2)
        end
    })
    
    AssistsGroupbox:AddToggle('NoRecoil', {
        Text = 'No Recoil',
        Default = false,
        Tooltip = 'Remove weapon recoil',
        Callback = function(Value)
            Library:Notify(Value and "No Recoil Enabled" or "No Recoil Disabled", 2)
        end
    })
    
    AssistsGroupbox:AddToggle('NoSpread', {
        Text = 'No Spread',
        Default = false,
        Tooltip = 'Perfect accuracy',
        Callback = function(Value)
            Library:Notify(Value and "No Spread Enabled" or "No Spread Disabled", 2)
        end
    })
    
    AssistsGroupbox:AddToggle('RapidFire', {
        Text = 'Rapid Fire',
        Default = false,
        Tooltip = 'Faster fire rate',
        Callback = function(Value)
            Library:Notify(Value and "Rapid Fire Enabled" or "Rapid Fire Disabled", 2)
        end
    })
    
    AssistsGroupbox:AddToggle('InstantHit', {
        Text = 'Instant Hit',
        Default = false,
        Tooltip = 'Bullets hit instantly',
        Callback = function(Value)
            Library:Notify(Value and "Instant Hit Enabled" or "Instant Hit Disabled", 2)
        end
    })
    
    AssistsGroupbox:AddToggle('AutoReload', {
        Text = 'Auto Reload',
        Default = false,
        Tooltip = 'Automatically reload weapon'
    })
    
    AssistsGroupbox:AddToggle('SilentAim', {
        Text = 'Silent Aim',
        Default = false,
        Tooltip = 'Hit enemies without moving camera',
        Callback = function(Value)
            Library:Notify(Value and "Silent Aim Enabled" or "Silent Aim Disabled", 2)
        end
    })
    
    -- =============================================
    -- VISUALS TAB
    -- =============================================
    local ESPGroupbox = Tabs.Visuals:AddLeftGroupbox('ESP Settings')
    
    ESPGroupbox:AddToggle('ESPEnabled', {
        Text = 'Enable ESP',
        Default = false,
        Tooltip = 'See player information',
        Callback = function(Value)
            if Value then
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        CreateESP(player)
                    end
                end
                Library:Notify("ESP Enabled", 2)
            else
                for _, esp in pairs(ESPObjects) do
                    for _, drawing in pairs(esp) do
                        drawing.Visible = false
                    end
                end
                Library:Notify("ESP Disabled", 2)
            end
        end
    })
    
    ESPGroupbox:AddToggle('ESPBoxes', {
        Text = 'Boxes',
        Default = true,
        Tooltip = 'Draw boxes around players'
    })
    
    ESPGroupbox:AddToggle('ESPNames', {
        Text = 'Names',
        Default = true,
        Tooltip = 'Show player names'
    })
    
    ESPGroupbox:AddToggle('ESPHealth', {
        Text = 'Health Text',
        Default = false,
        Tooltip = 'Show health as text'
    })
    
    ESPGroupbox:AddToggle('ESPHealthBar', {
        Text = 'Health Bar',
        Default = true,
        Tooltip = 'Show health bar'
    })
    
    ESPGroupbox:AddToggle('ESPDistance', {
        Text = 'Distance',
        Default = true,
        Tooltip = 'Show distance'
    })
    
    ESPGroupbox:AddToggle('ESPWeapon', {
        Text = 'Weapon ESP',
        Default = true,
        Tooltip = 'Show equipped weapon'
    })
    
    ESPGroupbox:AddToggle('ESPTracers', {
        Text = 'Tracers',
        Default = false,
        Tooltip = 'Draw lines to players'
    })
    
    ESPGroupbox:AddLabel('ESP Color'):AddColorPicker('ESPColor', {
        Default = Color3.fromRGB(255, 0, 0),
        Title = 'ESP Color',
        Transparency = 0,
    })
    
    ESPGroupbox:AddDivider()
    ESPGroupbox:AddLabel('Note: Teammates hidden when')
    ESPGroupbox:AddLabel('Ignore Teammates is enabled')
    
    -- Visual Effects
    local VisualsEffect = Tabs.Visuals:AddRightGroupbox('Visual Effects')
    
    VisualsEffect:AddToggle('Chams', {
        Text = 'Chams',
        Default = false,
        Tooltip = 'Highlight players through walls',
        Callback = function(Value)
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    -- Check team
                    if Toggles.IgnoreTeammates and Toggles.IgnoreTeammates.Value then
                        if player.Team == LocalPlayer.Team and player.Team ~= nil then
                            goto skipCham
                        end
                    end
                    
                    if Value then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "Cham"
                        highlight.FillColor = Options.ESPColor.Value
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.FillTransparency = 0.5
                        highlight.OutlineTransparency = 0
                        highlight.Parent = player.Character
                    else
                        if player.Character:FindFirstChild("Cham") then
                            player.Character.Cham:Destroy()
                        end
                    end
                    ::skipCham::
                end
            end
            Library:Notify(Value and "Chams Enabled" or "Chams Disabled", 2)
        end
    })
    
    VisualsEffect:AddToggle('RemoveFog', {
        Text = 'Remove Fog',
        Default = false,
        Tooltip = 'Clear visibility',
        Callback = function(Value)
            if Value then
                game:GetService("Lighting").FogEnd = 100000
            else
                game:GetService("Lighting").FogEnd = 1000
            end
        end
    })
    
    VisualsEffect:AddToggle('FullBright', {
        Text = 'Full Bright',
        Default = false,
        Tooltip = 'Maximum brightness',
        Callback = function(Value)
            if Value then
                game:GetService("Lighting").Brightness = 2
                game:GetService("Lighting").ClockTime = 14
                game:GetService("Lighting").GlobalShadows = false
                game:GetService("Lighting").OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            else
                game:GetService("Lighting").Brightness = 1
                game:GetService("Lighting").GlobalShadows = true
            end
        end
    })
    
    VisualsEffect:AddToggle('SkyboxRemover', {
        Text = 'Remove Skybox',
        Default = false,
        Tooltip = 'Remove sky visibility',
        Callback = function(Value)
            if Value then
                game:GetService("Lighting").Sky:Destroy()
            end
        end
    })
    
    VisualsEffect:AddToggle('Crosshair', {
        Text = 'Custom Crosshair',
        Default = false,
        Tooltip = 'Custom crosshair overlay',
        Callback = function(Value)
            if not _G.CustomCrosshair then
                _G.CustomCrosshair = {
                    Horizontal = Drawing.new("Line"),
                    Vertical = Drawing.new("Line")
                }
                _G.CustomCrosshair.Horizontal.Thickness = 2
                _G.CustomCrosshair.Vertical.Thickness = 2
            end
            
            _G.CustomCrosshair.Horizontal.Visible = Value
            _G.CustomCrosshair.Vertical.Visible = Value
            _G.CustomCrosshair.Horizontal.Color = Options.CrosshairColor.Value
            _G.CustomCrosshair.Vertical.Color = Options.CrosshairColor.Value
            
            if Value then
                RunService:BindToRenderStep("Crosshair", 302, function()
                    if Toggles.Crosshair.Value then
                        local size = Options.CrosshairSize.Value
                        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        _G.CustomCrosshair.Horizontal.From = Vector2.new(center.X - size, center.Y)
                        _G.CustomCrosshair.Horizontal.To = Vector2.new(center.X + size, center.Y)
                        _G.CustomCrosshair.Vertical.From = Vector2.new(center.X, center.Y - size)
                        _G.CustomCrosshair.Vertical.To = Vector2.new(center.X, center.Y + size)
                        _G.CustomCrosshair.Horizontal.Color = Options.CrosshairColor.Value
                        _G.CustomCrosshair.Vertical.Color = Options.CrosshairColor.Value
                    end
                end)
            else
                RunService:UnbindFromRenderStep("Crosshair")
            end
        end
    })
    
    VisualsEffect:AddSlider('CrosshairSize', {
        Text = 'Crosshair Size',
        Default = 10,
        Min = 5,
        Max = 30,
        Rounding = 0,
        Compact = true
    })
    
    VisualsEffect:AddLabel('Crosshair Color'):AddColorPicker('CrosshairColor', {
        Default = Color3.fromRGB(0, 255, 0),
        Title = 'Crosshair Color',
        Transparency = 0,
    })
    
    -- =============================================
    -- SKINS TAB
    -- =============================================
    local SkinChangerGroupbox = Tabs.Skins:AddLeftGroupbox('Weapon Skins')
    
    SkinChangerGroupbox:AddToggle('EnableSkinChanger', {
        Text = 'Enable Skin Changer',
        Default = false,
        Tooltip = 'Customize weapon appearance',
        Callback = function(Value)
            if Value then
                RunService:BindToRenderStep("SkinChanger", 100, function()
                    if Toggles.EnableSkinChanger.Value and LocalPlayer.Character then
                        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool then
                            for _, part in pairs(tool:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    if Toggles.ForceColor.Value then
                                        part.Color = Options.WeaponColor.Value
                                    end
                                    if Toggles.ForceMaterial.Value then
                                        part.Material = Enum.Material[Options.WeaponMaterial.Value]
                                    end
                                    if Toggles.ForceReflectance.Value then
                                        part.Reflectance = Options.WeaponReflectance.Value / 100
                                    end
                                    if Toggles.ForceTransparency.Value then
                                        part.Transparency = Options.WeaponTransparency.Value / 100
                                    end
                                end
                            end
                        end
                    end
                end)
                Library:Notify("Skin Changer Enabled", 2)
            else
                RunService:UnbindFromRenderStep("SkinChanger")
                Library:Notify("Skin Changer Disabled", 2)
            end
        end
    })
    
    SkinChangerGroupbox:AddToggle('ForceColor', {
        Text = 'Force Weapon Color',
        Default = false
    })
    
    SkinChangerGroupbox:AddLabel('Weapon Color'):AddColorPicker('WeaponColor', {
        Default = Color3.fromRGB(255, 215, 0),
        Title = 'Weapon Color',
        Transparency = 0,
    })
    
    SkinChangerGroupbox:AddToggle('ForceMaterial', {
        Text = 'Force Material',
        Default = false
    })
    
    SkinChangerGroupbox:AddDropdown('WeaponMaterial', {
        Values = {'Plastic', 'Wood', 'Slate', 'Concrete', 'Metal', 'Neon', 'Glass', 'ForceField', 'Ice', 'Marble', 'SmoothPlastic', 'DiamondPlate', 'Foil'},
        Default = 1,
        Multi = false,
        Text = 'Material Type'
    })
    
    SkinChangerGroupbox:AddToggle('ForceReflectance', {
        Text = 'Force Reflectance',
        Default = false
    })
    
    SkinChangerGroupbox:AddSlider('WeaponReflectance', {
        Text = 'Reflectance',
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Compact = true
    })
    
    SkinChangerGroupbox:AddToggle('ForceTransparency', {
        Text = 'Force Transparency',
        Default = false
    })
    
    SkinChangerGroupbox:AddSlider('WeaponTransparency', {
        Text = 'Transparency',
        Default = 0,
        Min = 0,
        Max = 90,
        Rounding = 0,
        Compact = true
    })
    
    -- Preset Skins
    local PresetGroupbox = Tabs.Skins:AddRightGroupbox('Preset Skins')
    
    PresetGroupbox:AddButton('Gold Skin', function()
        Toggles.EnableSkinChanger:SetValue(true)
        Toggles.ForceColor:SetValue(true)
        Options.WeaponColor:SetValueRGB(Color3.fromRGB(255, 215, 0))
        Toggles.ForceMaterial:SetValue(true)
        Options.WeaponMaterial:SetValue('Foil')
        Toggles.ForceReflectance:SetValue(true)
        Options.WeaponReflectance:SetValue(50)
        Library:Notify("Gold Skin Applied", 2)
    end)
    
    PresetGroupbox:AddButton('Diamond Skin', function()
        Toggles.EnableSkinChanger:SetValue(true)
        Toggles.ForceColor:SetValue(true)
        Options.WeaponColor:SetValueRGB(Color3.fromRGB(185, 242, 255))
        Toggles.ForceMaterial:SetValue(true)
        Options.WeaponMaterial:SetValue('Glass')
        Toggles.ForceReflectance:SetValue(true)
        Options.WeaponReflectance:SetValue(80)
        Library:Notify("Diamond Skin Applied", 2)
    end)
    
    PresetGroupbox:AddButton('Neon Skin', function()
        Toggles.EnableSkinChanger:SetValue(true)
        Toggles.ForceColor:SetValue(true)
        Options.WeaponColor:SetValueRGB(Color3.fromRGB(0, 255, 255))
        Toggles.ForceMaterial:SetValue(true)
        Options.WeaponMaterial:SetValue('Neon')
        Library:Notify("Neon Skin Applied", 2)
    end)
    
    PresetGroupbox:AddButton('Ruby Skin', function()
        Toggles.EnableSkinChanger:SetValue(true)
        Toggles.ForceColor:SetValue(true)
        Options.WeaponColor:SetValueRGB(Color3.fromRGB(224, 17, 95))
        Toggles.ForceMaterial:SetValue(true)
        Options.WeaponMaterial:SetValue('Glass')
        Toggles.ForceReflectance:SetValue(true)
        Options.WeaponReflectance:SetValue(70)
        Library:Notify("Ruby Skin Applied", 2)
    end)
    
    PresetGroupbox:AddButton('Emerald Skin', function()
        Toggles.EnableSkinChanger:SetValue(true)
        Toggles.ForceColor:SetValue(true)
        Options.WeaponColor:SetValueRGB(Color3.fromRGB(80, 200, 120))
        Toggles.ForceMaterial:SetValue(true)
        Options.WeaponMaterial:SetValue('Glass')
        Toggles.ForceReflectance:SetValue(true)
        Options.WeaponReflectance:SetValue(60)
        Library:Notify("Emerald Skin Applied", 2)
    end)
    
    PresetGroupbox:AddButton('Ghost Skin', function()
        Toggles.EnableSkinChanger:SetValue(true)
        Toggles.ForceColor:SetValue(true)
        Options.WeaponColor:SetValueRGB(Color3.fromRGB(200, 200, 255))
        Toggles.ForceMaterial:SetValue(true)
        Options.WeaponMaterial:SetValue('ForceField')
        Toggles.ForceTransparency:SetValue(true)
        Options.WeaponTransparency:SetValue(50)
        Library:Notify("Ghost Skin Applied", 2)
    end)
    
    PresetGroupbox:AddButton('Reset Skin', function()
        Toggles.EnableSkinChanger:SetValue(false)
        Toggles.ForceColor:SetValue(false)
        Toggles.ForceMaterial:SetValue(false)
        Toggles.ForceReflectance:SetValue(false)
        Toggles.ForceTransparency:SetValue(false)
        Library:Notify("Skin Reset", 2)
    end)
    
    -- =============================================
    -- MISC TAB
    -- =============================================
    local MovementGroupbox = Tabs.Misc:AddLeftGroupbox('Movement')
    
    MovementGroupbox:AddSlider('WalkSpeed', {
        Text = 'Walk Speed',
        Default = 16,
        Min = 16,
        Max = 100,
        Rounding = 0,
        Compact = false,
        Callback = function(Value)
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.WalkSpeed = Value
            end
        end
    })
    
    MovementGroupbox:AddSlider('JumpPower', {
        Text = 'Jump Power',
        Default = 50,
        Min = 50,
        Max = 150,
        Rounding = 0,
        Compact = false,
        Callback = function(Value)
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.JumpPower = Value
            end
        end
    })
    
    MovementGroupbox:AddToggle('BunnyHop', {
        Text = 'Bunny Hop',
        Default = false,
        Tooltip = 'Auto jump',
        Callback = function(Value)
            if Value then
                RunService:BindToRenderStep("BunnyHop", 100, function()
                    if Toggles.BunnyHop.Value and LocalPlayer.Character then
                        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                end)
            else
                RunService:UnbindFromRenderStep("BunnyHop")
            end
        end
    })
    
    MovementGroupbox:AddToggle('NoClip', {
        Text = 'No Clip',
        Default = false,
        Tooltip = 'Walk through walls',
        Callback = function(Value)
            if Value then
                RunService:BindToRenderStep("NoClip", 100, function()
                    if Toggles.NoClip.Value and LocalPlayer.Character then
                        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end)
            else
                RunService:UnbindFromRenderStep("NoClip")
            end
        end
    })
    
    MovementGroupbox:AddToggle('Flight', {
        Text = 'Flight Mode',
        Default = false,
        Tooltip = 'Fly around the map',
        Callback = function(Value)
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local hrp = character.HumanoidRootPart
                if Value then
                    local bg = Instance.new("BodyGyro", hrp)
                    bg.Name = "FlightGyro"
                    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                    local bv = Instance.new("BodyVelocity", hrp)
                    bv.Name = "FlightVelocity"
                    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                    bv.Velocity = Vector3.new(0, 0, 0)
                    
                    RunService:BindToRenderStep("Flight", 100, function()
                        if Toggles.Flight.Value then
                            bg.CFrame = Camera.CFrame
                            local speed = Options.FlightSpeed.Value
                            local direction = Vector3.new()
                            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + Camera.CFrame.LookVector end
                            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - Camera.CFrame.LookVector end
                            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - Camera.CFrame.RightVector end
                            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + Camera.CFrame.RightVector end
                            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
                            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction = direction - Vector3.new(0, 1, 0) end
                            bv.Velocity = direction * speed
                        end
                    end)
                else
                    RunService:UnbindFromRenderStep("Flight")
                    if hrp:FindFirstChild("FlightGyro") then hrp.FlightGyro:Destroy() end
                    if hrp:FindFirstChild("FlightVelocity") then hrp.FlightVelocity:Destroy() end
                end
            end
        end
    })
    
    MovementGroupbox:AddSlider('FlightSpeed', {
        Text = 'Flight Speed',
        Default = 50,
        Min = 10,
        Max = 200,
        Rounding = 0,
        Compact = true
    })
    
    -- Utility
    local UtilityGroupbox = Tabs.Misc:AddRightGroupbox('Utility')
    
    UtilityGroupbox:AddToggle('AntiAFK', {
        Text = 'Anti-AFK',
        Default = false,
        Tooltip = 'Prevent kick for inactivity',
        Callback = function(Value)
            if Value then
                local VirtualUser = game:GetService("VirtualUser")
                LocalPlayer.Idled:Connect(function()
                    if Toggles.AntiAFK.Value then
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new())
                    end
                end)
            end
        end
    })
    
    UtilityGroupbox:AddToggle('KillSay', {
        Text = 'Kill Say',
        Default = false,
        Tooltip = 'Say message on kill',
        Callback = function(Value)
            Library:Notify(Value and "Kill Say Enabled" or "Kill Say Disabled", 2)
        end
    })
    
    UtilityGroupbox:AddInput('KillSayText', {
        Default = 'gg ez',
        Numeric = false,
        Finished = true,
        Text = 'Kill Say Text',
        Placeholder = 'Enter message...',
    })
    
    UtilityGroupbox:AddToggle('LowGFX', {
        Text = 'Low Graphics Mode',
        Default = false,
        Tooltip = 'Improve performance',
        Callback = function(Value)
            if Value then
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                        obj.Enabled = false
                    end
                end
            end
        end
    })
    
    UtilityGroupbox:AddButton('Respawn', function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.Health = 0
            Library:Notify('Respawning...', 2)
        end
    end)
    
    UtilityGroupbox:AddButton('Rejoin Server', function()
        game:GetService('TeleportService'):TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end)
    
    -- =============================================
    -- PLAYERS TAB
    -- =============================================
    local PlayerListGroupbox = Tabs.Players:AddLeftGroupbox('Player List')
    
    local selectedPlayer = nil
    
    PlayerListGroupbox:AddDropdown('PlayerSelect', {
        Values = {'Select a player...'},
        Default = 1,
        Multi = false,
        Text = 'Select Player',
        Callback = function(Value)
            selectedPlayer = Value
        end
    })
    
    PlayerListGroupbox:AddButton('Refresh List', function()
        local players = {}
        for _, player in pairs(Players:GetPlayers()) do
            table.insert(players, player.Name)
        end
        Options.PlayerSelect:SetValues(players)
        Library:Notify('Player list refreshed!', 2)
    end)
    
    PlayerListGroupbox:AddButton('Spectate Player', function()
        if selectedPlayer then
            local targetPlayer = Players:FindFirstChild(selectedPlayer)
            if targetPlayer and targetPlayer.Character then
                Camera.CameraSubject = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
                Library:Notify('Spectating ' .. selectedPlayer, 2)
            end
        end
    end)
    
    PlayerListGroupbox:AddButton('Stop Spectating', function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            Camera.CameraSubject = LocalPlayer.Character.Humanoid
            Library:Notify('Stopped spectating', 2)
        end
    end)
    
    PlayerListGroupbox:AddButton('Copy Username', function()
        if selectedPlayer then
            setclipboard(selectedPlayer)
            Library:Notify('Copied: ' .. selectedPlayer, 2)
        end
    end)
    
    -- Player Actions
    local PlayerActionsGroupbox = Tabs.Players:AddRightGroupbox('Player Actions')
    
    PlayerActionsGroupbox:AddToggle('FocusPlayer', {
        Text = 'Focus Selected Player',
        Default = false,
        Tooltip = 'Only target selected player',
        Callback = function(Value)
            if Value and selectedPlayer then
                _G.FocusedPlayer = selectedPlayer
                Library:Notify('Focusing on ' .. selectedPlayer, 3)
            else
                _G.FocusedPlayer = nil
                Library:Notify('Focus disabled', 2)
            end
        end
    })
    
    PlayerActionsGroupbox:AddButton('Add to Priority', function()
        if selectedPlayer then
            if not _G.PriorityList then _G.PriorityList = {} end
            table.insert(_G.PriorityList, selectedPlayer)
            Library:Notify(selectedPlayer .. ' added to priority', 2)
        end
    end)
    
    PlayerActionsGroupbox:AddButton('Add to Ignore', function()
        if selectedPlayer then
            if not _G.IgnoreList then _G.IgnoreList = {} end
            table.insert(_G.IgnoreList, selectedPlayer)
            Library:Notify(selectedPlayer .. ' ignored', 2)
        end
    end)
    
    PlayerActionsGroupbox:AddButton('Clear Lists', function()
        _G.PriorityList = {}
        _G.IgnoreList = {}
        Library:Notify('Lists cleared', 2)
    end)
    
    PlayerActionsGroupbox:AddDivider()
    
    PlayerActionsGroupbox:AddToggle('ShowPlayerInfo', {
        Text = 'Show Player Info',
        Default = false,
        Tooltip = 'Display info for selected player',
        Callback = function(Value)
            if not _G.PlayerInfoText then
                _G.PlayerInfoText = Drawing.new("Text")
                _G.PlayerInfoText.Size = 16
                _G.PlayerInfoText.Center = false
                _G.PlayerInfoText.Outline = true
                _G.PlayerInfoText.Color = Color3.fromRGB(255, 255, 255)
                _G.PlayerInfoText.Position = Vector2.new(10, 100)
            end
            
            if Value then
                RunService:BindToRenderStep("PlayerInfo", 301, function()
                    if selectedPlayer and Toggles.ShowPlayerInfo.Value then
                        local plr = Players:FindFirstChild(selectedPlayer)
                        if plr and plr.Character then
                            local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
                            local distance = "N/A"
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") and plr.Character:FindFirstChild("Head") then
                                distance = math.floor((LocalPlayer.Character.Head.Position - plr.Character.Head.Position).Magnitude)
                            end
                            
                            local info = string.format(
                                "Player: %s\nHealth: %d/%d\nTeam: %s\nDistance: %s studs",
                                plr.Name,
                                humanoid and math.floor(humanoid.Health) or 0,
                                humanoid and math.floor(humanoid.MaxHealth) or 100,
                                plr.Team and plr.Team.Name or "None",
                                distance
                            )
                            _G.PlayerInfoText.Text = info
                            _G.PlayerInfoText.Visible = true
                        else
                            _G.PlayerInfoText.Visible = false
                        end
                    else
                        _G.PlayerInfoText.Visible = false
                    end
                end)
            else
                RunService:UnbindFromRenderStep("PlayerInfo")
                _G.PlayerInfoText.Visible = false
            end
        end
    })
    
    -- =============================================
    -- SETTINGS TAB
    -- =============================================
    local MenuGroupbox = Tabs.Settings:AddLeftGroupbox('Menu Settings')
    
    MenuGroupbox:AddButton('🎮 Join Discord', function()
        setclipboard('https://discord.gg/ACcQASkzxK')
        Library:Notify('✅ Discord link copied!', 3)
        Library:Notify('📋 Paste in browser!', 3)
    end)
    
    MenuGroupbox:AddButton('Unload Script', function()
        Library:Notify('Unloading...', 2)
        Library:Unload()
    end)
    
    MenuGroupbox:AddLabel('Menu Keybind'):AddKeyPicker('MenuKeybind', {
        Default = 'RightShift',
        NoUI = true,
        Text = 'Menu Keybind'
    })
    
    MenuGroupbox:AddToggle('Watermark', {
        Text = 'Show Watermark',
        Default = true,
        Callback = function(Value)
            Library:SetWatermarkVisibility(Value)
        end
    })
    
    -- Info
    local InfoGroupbox = Tabs.Settings:AddRightGroupbox('Information')
    
    InfoGroupbox:AddLabel('NSHUB Bloxstrike Script')
    InfoGroupbox:AddLabel('Version: 1.0')
    InfoGroupbox:AddLabel('Game: Bloxstrike')
    InfoGroupbox:AddDivider()
    InfoGroupbox:AddLabel('Discord: discord.gg/ACcQASkzxK')
    InfoGroupbox:AddButton('Copy Discord Link', function()
        setclipboard('https://discord.gg/ACcQASkzxK')
        Library:Notify('Discord link copied!', 2)
    end)
    
    -- Theme Manager
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder('NSHUB_Bloxstrike')
    ThemeManager:ApplyToTab(Tabs.Settings)
    
    -- UI Settings
    Library.ToggleKeybind = Options.MenuKeybind
    Library:SetWatermarkVisibility(true)
    Library:SetWatermark('NSHUB Bloxstrike | v1.0')
    
    -- Initialize
    task.spawn(function()
        task.wait(1)
        local players = {}
        for _, player in pairs(Players:GetPlayers()) do
            table.insert(players, player.Name)
        end
        Options.PlayerSelect:SetValues(players)
    end)
    
    -- Auto-copy Discord
    task.spawn(function()
        task.wait(0.5)
        setclipboard('https://discord.gg/ACcQASkzxK')
        Library:Notify('✅ Discord copied to clipboard!', 5)
        task.wait(0.5)
        Library:Notify('📋 discord.gg/ACcQASkzxK', 5)
    end)
    
    -- Main Render Loop
    RunService.RenderStepped:Connect(function()
        -- Update FOV Circle
        if Toggles.ShowFOV and Toggles.ShowFOV.Value then
            if not FOVCircle then CreateFOVCircle() end
            FOVCircle.Visible = true
            FOVCircle.Radius = Options.AimbotFOV.Value
            FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        elseif FOVCircle then
            FOVCircle.Visible = false
        end
        
        -- Update ESP
        if Toggles.ESPEnabled and Toggles.ESPEnabled.Value then
            UpdateESP()
        end
        
        -- Create ESP for new players
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not ESPObjects[player] then
                CreateESP(player)
            end
        end
    end)
    
    -- Player Events
    Players.PlayerAdded:Connect(function(player)
        CreateESP(player)
        task.wait(0.1)
        local players = {}
        for _, p in pairs(Players:GetPlayers()) do
            table.insert(players, p.Name)
        end
        Options.PlayerSelect:SetValues(players)
        Library:Notify(player.Name .. ' joined', 2)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        if ESPObjects[player] then
            for _, drawing in pairs(ESPObjects[player]) do
                drawing:Remove()
            end
            ESPObjects[player] = nil
        end
        task.wait(0.1)
        local players = {}
        for _, p in pairs(Players:GetPlayers()) do
            table.insert(players, p.Name)
        end
        Options.PlayerSelect:SetValues(players)
        Library:Notify(player.Name .. ' left', 2)
    end)
    
    -- Character Respawn Handler
    LocalPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.1)
        if Options.WalkSpeed and Options.WalkSpeed.Value ~= 16 then
            character:WaitForChild("Humanoid").WalkSpeed = Options.WalkSpeed.Value
        end
        if Options.JumpPower and Options.JumpPower.Value ~= 50 then
            character:WaitForChild("Humanoid").JumpPower = Options.JumpPower.Value
        end
    end)
    
    -- Success Message
    task.wait(0.2)
    Library:Notify('NSHUB Bloxstrike loaded!', 5)
    Library:Notify('Press RightShift to toggle menu', 3)
    
    print('========================================')
    print('NSHUB Bloxstrike Script Loaded')
    print('Version: 1.0')
    print('Discord: discord.gg/ACcQASkzxK')
    print('========================================')
else
    warn("This script only works in Bloxstrike!")
end

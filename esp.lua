local ESP = {}
ESP.__index = ESP

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local utils = loadstring(game:HttpGet("https://raw.githubusercontent.com/dhsoares01/Esp-library-/refs/heads/main/utils.lua"))()

local targetObject = nil
local currentPath = nil
local drawingLine = nil

-- Atualiza o alvo
function ESP:SetTarget(object)
    targetObject = object
    self:UpdatePath()
end

-- Cria/atualiza o path até o alvo
function ESP:UpdatePath()
    if not targetObject or not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    
    local startPos = Character.HumanoidRootPart.Position
    local targetPos = targetObject.Position
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 7,
        AgentMaxSlope = 45
    })
    
    path:ComputeAsync(startPos, targetPos)
    
    if path.Status == Enum.PathStatus.Complete then
        currentPath = path
    else
        currentPath = nil
    end
end

-- Desenha linha ESP
function ESP:DrawLine()
    if drawingLine then
        drawingLine:Remove()
        drawingLine = nil
    end

    if not targetObject then return end

    drawingLine = Drawing.new("Line")
    drawingLine.Color = Color3.fromRGB(255, 0, 0)
    drawingLine.Thickness = 2
    drawingLine.Transparency = 1
end

-- Atualiza linha a cada frame
RunService.RenderStepped:Connect(function()
    if drawingLine and targetObject and Character and Character:FindFirstChild("HumanoidRootPart") then
        local screenPos1, onScreen1 = workspace.CurrentCamera:WorldToViewportPoint(Character.HumanoidRootPart.Position)
        local screenPos2, onScreen2 = workspace.CurrentCamera:WorldToViewportPoint(targetObject.Position)
        
        if onScreen1 and onScreen2 then
            drawingLine.Visible = true
            drawingLine.From = Vector2.new(screenPos1.X, screenPos1.Y)
            drawingLine.To = Vector2.new(screenPos2.X, screenPos2.Y)
        else
            drawingLine.Visible = false
        end
    end
end)

-- Atualiza dinamicamente a rota
RunService.Heartbeat:Connect(function()
    ESP:UpdatePath()
end)

return ESP

-- ESP Library by GitHub.com/yourusername
-- Versão 1.0 - Orientada a Endereço de Objeto

local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

-- Configurações padrão
local DEFAULT_SETTINGS = {
    LineColor = Color3.fromRGB(255, 50, 50),
    LineThickness = 0.1,
    RefreshRate = 0.1, -- segundos
    MaxDistance = 500, -- studs
    WaypointSize = 2,
    WaypointColor = Color3.fromRGB(0, 255, 0),
    DynamicPathfinding = true
}

-- Inicializa uma nova instância ESP
function ESPLibrary.new(targetObject, options)
    local self = setmetatable({}, ESPLibrary)
    
    -- Validar objeto alvo
    if not targetObject or not targetObject:IsA("BasePart") then
        error("Target object must be a BasePart")
    end
    
    self.Target = targetObject
    self.Settings = options or DEFAULT_SETTINGS
    self.Active = false
    self.Connections = {}
    self.Waypoints = {}
    self.CurrentPath = {}
    
    -- Inicializar partes visuais
    self:InitializeVisuals()
    
    return self
end

-- Inicializa os componentes visuais
function ESPLibrary:InitializeVisuals()
    -- Linha principal
    self.Beam = Instance.new("Part")
    self.Beam.Size = Vector3.new(self.Settings.LineThickness, self.Settings.LineThickness, 1)
    self.Beam.Material = Enum.Material.Neon
    self.Beam.Color = self.Settings.LineColor
    self.Beam.Anchored = true
    self.Beam.CanCollide = false
    self.Beam.Transparency = 0.7
    
    -- Adicionar Attachment para Beam
    self.StartAttachment = Instance.new("Attachment")
    self.EndAttachment = Instance.new("Attachment")
    
    self.BeamAttachment = Instance.new("Beam")
    self.BeamAttachment.Color = ColorSequence.new(self.Settings.LineColor)
    self.BeamAttachment.Width0 = self.Settings.LineThickness
    self.BeamAttachment.Width1 = self.Settings.LineThickness
    self.BeamAttachment.Attachment0 = self.StartAttachment
    self.BeamAttachment.Attachment1 = self.EndAttachment
    self.BeamAttachment.Parent = self.Beam
    
    self.Beam.Parent = workspace.Terrain
end

-- Ativa/desativa o ESP
function ESPLibrary:Toggle(active)
    if active == self.Active then return end
    
    self.Active = active
    self.Beam.Transparency = active and 0.3 or 1
    
    if active then
        self:StartUpdating()
    else
        self:StopUpdating()
    end
end

-- Inicia a atualização do ESP
function ESPLibrary:StartUpdating()
    self:StopUpdating() -- Garantir que não há atualizações duplicadas
    
    local updateConnection
    local lastUpdate = 0
    
    updateConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        lastUpdate = lastUpdate + dt
        if lastUpdate >= self.Settings.RefreshRate then
            self:UpdateESP()
            lastUpdate = 0
        end
    end)
    
    table.insert(self.Connections, updateConnection)
end

-- Para a atualização do ESP
function ESPLibrary:StopUpdating()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Connections = {}
end

-- Atualiza a posição e o caminho do ESP
function ESPLibrary:UpdateESP()
    local character = game.Players.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    if not self.Target or not self.Target.Parent then
        self:Toggle(false)
        return
    end
    
    local humanoidRootPart = character.HumanoidRootPart
    local targetPosition = self.Target.Position
    
    -- Verificar distância máxima
    if (humanoidRootPart.Position - targetPosition).Magnitude > self.Settings.MaxDistance then
        self.Beam.Transparency = 1
        return
    else
        self.Beam.Transparency = 0.3
    end
    
    -- Atualizar pathfinding se necessário
    if self.Settings.DynamicPathfinding then
        self:CalculatePath(humanoidRootPart.Position, targetPosition)
    else
        -- Linha direta se pathfinding estiver desativado
        self.StartAttachment.WorldPosition = humanoidRootPart.Position + Vector3.new(0, 2, 0)
        self.EndAttachment.WorldPosition = targetPosition
    end
end

-- Calcula o caminho usando Raycasting para evitar obstáculos
function ESPLibrary:CalculatePath(startPos, endPos)
    -- Limpar waypoints antigos
    self:ClearWaypoints()
    
    -- Raycast para verificar visão direta
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
    local raycastResult = workspace:Raycast(startPos, direction * distance, raycastParams)
    
    if not raycastResult then
        -- Caminho direto sem obstáculos
        self.StartAttachment.WorldPosition = startPos + Vector3.new(0, 2, 0)
        self.EndAttachment.WorldPosition = endPos
        return
    end
    
    -- Se houver obstáculo, calcular waypoints
    self:FindPathAroundObstacle(startPos, endPos, raycastResult.Position)
end

-- Encontra caminho ao redor de obstáculos (implementação simplificada)
function ESPLibrary:FindPathAroundObstacle(startPos, endPos, hitPosition)
    -- Esta é uma implementação simplificada - sistemas reais usariam A* ou outros algoritmos
    
    -- 1. Calcular direções alternativas
    local upVector = Vector3.new(0, 1, 0)
    local rightVector = (endPos - startPos):Cross(upVector).Unit
    
    -- 2. Testar rotas alternativas
    local testDirections = {
        upVector, -- Para cima
        -upVector, -- Para baixo (pode não ser útil)
        rightVector, -- Para a direita
        -rightVector -- Para a esquerda
    }
    
    local bestPath = {}
    local shortestDistance = math.huge
    
    for _, dir in ipairs(testDirections) do
        local waypoint = hitPosition + dir * 5 -- 5 studs de desvio
        
        -- Verificar se este caminho é melhor
        local pathDistance = (startPos - waypoint).Magnitude + (waypoint - endPos).Magnitude
        if pathDistance < shortestDistance then
            shortestDistance = pathDistance
            bestPath = {waypoint}
        end
    end
    
    -- Atualizar o caminho com os waypoints
    self.CurrentPath = bestPath
    self:UpdatePathVisuals(startPos, endPos, bestPath)
end

-- Atualiza os visuais do caminho
function ESPLibrary:UpdatePathVisuals(startPos, endPos, waypoints)
    -- Posicionar attachments para criar linhas segmentadas
    if #waypoints == 0 then
        self.StartAttachment.WorldPosition = startPos + Vector3.new(0, 2, 0)
        self.EndAttachment.WorldPosition = endPos
    else
        -- Criar linhas para cada segmento do caminho
        self.StartAttachment.WorldPosition = startPos + Vector3.new(0, 2, 0)
        
        -- Criar waypoints visuais
        for i, waypoint in ipairs(waypoints) do
            if not self.Waypoints[i] then
                self.Waypoints[i] = Instance.new("Part")
                self.Waypoints[i].Size = Vector3.new(self.Settings.WaypointSize, self.Settings.WaypointSize, self.Settings.WaypointSize)
                self.Waypoints[i].Shape = Enum.PartType.Ball
                self.Waypoints[i].Material = Enum.Material.Neon
                self.Waypoints[i].Color = self.Settings.WaypointColor
                self.Waypoints[i].Anchored = true
                self.Waypoints[i].CanCollide = false
                self.Waypoints[i].Parent = workspace.Terrain
            end
            
            self.Waypoints[i].Position = waypoint
        end
        
        -- Para simplificação, estamos usando apenas um waypoint
        if #waypoints > 0 then
            self.EndAttachment.WorldPosition = waypoints[1]
        end
    end
end

-- Limpa waypoints visuais
function ESPLibrary:ClearWaypoints()
    for _, waypoint in ipairs(self.Waypoints) do
        waypoint:Destroy()
    end
    self.Waypoints = {}
end

-- Destruir a instância ESP
function ESPLibrary:Destroy()
    self:Toggle(false)
    self.Beam:Destroy()
    self:ClearWaypoints()
    
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
end

return ESPLibrary

local utils = {}

-- Exemplo: Raycast para saber se o caminho está livre
function utils:IsPathClear(startPos, endPos)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true

    local result = workspace:Raycast(startPos, (endPos - startPos).Unit * (endPos - startPos).Magnitude, params)
    return not result
end

return utils

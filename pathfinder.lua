local astar = {
    maxtime = 1/3,
    interval = 14,-- must be a natural integer
    ignorelist = { workspace.Players, workspace.Ignore, workspace.Camera, workspace.Terrain },
    performance = false -- not tested
}

local nodemetatable = {__index = function(self, index)
	if not rawget(self, index) then
		rawset(self, index, setmetatable({}, {__index = function(self0, index0)
			if not rawget(self0, index0) then
				rawset(self0, index0, {})
			end

			return rawget(self0, index0)
		end}))
	end

	return rawget(self, index)
end}

local directions = {
	space = {
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, -1, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1)
	},
	diagonal = {
		Vector3.new(1, 0, 1),
		Vector3.new(1, 0, -1),
		Vector3.new(-1, 0, 1),
		Vector3.new(-1, 0, -1),
		Vector3.new(1, 1, 0),
		Vector3.new(1, -1, 0),
		Vector3.new(-1, 1, 0),
		Vector3.new(-1, -1, 0),
		Vector3.new(0, 1, 1),
		Vector3.new(0, -1, 1),
		Vector3.new(0, 1, -1),
		Vector3.new(0, -1, -1)
	},
}

local workspace = game:GetService("Workspace")
local parameters = RaycastParams.new()
local insert = table.insert

parameters.FilterType = Enum.RaycastFilterType.Blacklist

function astar:distance(origin, target)
	local ox, oy, oz = origin.X, origin.Y, origin.Z
	local tx, ty, tz = target.X, target.Y, target.Z
	return ((ox - tx) ^ 2 + (oy - ty) ^ 2 + (oz - tz) ^ 2) ^ 0.5
end

function astar:findpart(origin, target)
	return workspace:Raycast(origin, target - origin, parameters)
end

function astar:findpath(origin, target, interval, maxoffset)
	local types = {space = astar.interval, diagonal = 2 ^ 0.5 * astar.interval}
	local nodes = setmetatable({}, nodemetatable)
	local endtime = tick() + astar.maxtime
	local starttime = tick()
	local path, distance

	parameters.FilterDescendantsInstances = astar.ignorelist
	nodes[0][0][0] = {
		hcost = self:distance(origin, target),
		offset = Vector3.new(),
		scanned = false,
		position = origin,
		lastnode = nil,
		gcost = 0
	}
	nodes[0][0][0].fcost = nodes[0][0][0].hcost

	while tick() < endtime do
		local lowestcost, currentnode, x, y, z = math.huge

		for x1, x0 in next, nodes do
			for y1, y0 in next, x0 do
				for z1, randomnode in next, y0 do
					if not randomnode.scanned and randomnode.fcost < lowestcost then
						lowestcost = randomnode.fcost
						currentnode = randomnode
						x = x1; y = y1; z = z1
					end
				end
			end
		end

		if currentnode then
			if self:findpart(currentnode.position, target) and currentnode.hcost >= maxoffset then
				for offsettype, offsets in next, directions do
					for _, offset in next, offsets do
						offset = offset * types.space
						local offsetnode = nodes[x + offset.X][y + offset.Y][z + offset.Z]
						local position = currentnode.position + offset

						if not self:findpart(currentnode.position, position) then
							if offsetnode then
								if offsetnode.gcost > currentnode.gcost + types[offsettype] then
									offsetnode.gcost = currentnode.gcost + types[offsettype]
									offsetnode.fcost = offsetnode.gcost + offsetnode.hcost
									offsetnode.lastnode = currentnode
								end
							else
								nodes[x + offset.X][y + offset.Y][z + offset.Z] = {
									gcost = currentnode.gcost + types[offsettype],
									lastnode = currentnode,
									position = position,
									scanned = false
								}

								local offsetnode = nodes[x + offset.X][y + offset.Y][z + offset.Z]
								offsetnode.hcost = self:distance(offsetnode.position, target)
								offsetnode.fcost = offsetnode.hcost + offsetnode.gcost
							end
						end
					end
				end

				currentnode.scanned = true
			else
				local ignoreend = currentnode.hcost <= maxoffset -- untested
				path = {}

				while currentnode.lastnode do
					insert(path, 1, currentnode.position)
					currentnode = currentnode.lastnode
				end

				insert(path, 1, origin)
				currentnode = nodes[x][y][z]

				if astar.performance then
					local direction = (target - currentnode.position).Unit * types.space
					local lastgcost = self:distance(currentnode.position, target)
					distance = currentnode.gcost + lastgcost

					for i = 1, math.floor(lastgcost / types.space) do
						insert(path, currentnode.position + direction * i)
					end
				else
					local points = {origin}

					if not ignoreend then
						insert(path, target)
					end

					for i = 3, #path do
						if self:findpart(points[#points], path[i]) then
							insert(points, path[i - 1])
						end
					end

					insert(points, ignoreend and path[#path] or target)

					path = {}
					distance = 0

					for i = 2, #points do
						local startpos = points[i - 1]
						local endpos = points[i]
						local direction = (endpos - startpos).Unit * interval
						local pointdist = self:distance(startpos, endpos)
						distance = distance + pointdist
						
						for i = 1, math.floor(pointdist / interval) do
							insert(path, startpos + direction * i)
						end

						insert(path, endpos)
					end
				end

				endtime = tick()
				break
			end
		else
			endtime = tick()
			break
		end
	end

	return path, distance, endtime - starttime
end	

return astar

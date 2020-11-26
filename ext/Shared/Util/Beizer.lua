class 'Bezier'
 
function length(n, func, ...)
    local sum, ranges, sums = 0, {}, {}
    for i = 0, n-1 do
        local p1, p2 = func(i/n, ...), func((i+1)/n, ...)
        local dist = (p2 - p1).magnitude
        ranges[sum] = {dist, p1, p2}
        table.insert(sums, sum)
        sum = sum + dist
    end
    return sum, ranges, sums
end

function lerp(a, b, c)
    return a + (b - a) * c
end

function quadBezier(t, p0, p1, p2)
    print(t)
    print(p0)
    print(p1)
    print(p2)

    local l1 = lerp(p0, p1, t)
    local l2 = lerp(p1, p2, t)
    local quad = lerp(l1, l2, t)
    return quad
end
function Bezier:__init(n, ...)
    self.func = quadBezier
    local sum, ranges, sums = length(n, self.func, ...)
    self.n = n
    self.points = {...}
    self.length = sum
    self.ranges = ranges
    self.sums = sums
    return self
end
 
function Bezier:setPoints(...)
    -- only update the length when the control points are changed
    local sum, ranges, sums = length(self.n, self.func, ...)
    self.points = {...}
    self.length = sum
    self.ranges = ranges
    self.sums = sums
end
 
function Bezier:calc(t)
    -- if you don't need t to be a percentage of distance
    return self.func(t, unpack(self.points))
end
 
function Bezier:calcFixed(t)
    local T, near = t * self.length, 0
    for _, n in next, self.sums do
        if (T - n) < 0 then break end
        near = n
    end
    local set = self.ranges[near]
    local percent = (T - near)/set[1]
    return set[2], set[3], percent
end

 -- bzs is table with Bezier urves in it in order traveled
function Bezier:travelPath(t, bzs)
    local totalLength, sums = 0, {}
    -- get total length of all curves, also order sums for sorting
    for _, bz in next, bzs do
        table.insert(sums, totalLength)
        totalLength = totalLength + bz.length
    end
    -- get percentage of total distance and find the Bezier curve we're on
    local T, near, bz = t * totalLength, 0, bzs[1]
    for i, n in ipairs(sums) do
        if (T - n) < 0 then break end
        near, bz = n, bzs[i]
    end
    -- get relative percentage traveled on given Bezier curve
    local percent = (T - near)/bz.length
    -- lerp across curve by percentage
    local a, b, c = bz:calcFixed(percent)
    return a + (b - a) * c
end
return Bezier
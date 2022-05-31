function Vec3:Lerp(to, t)
	local from = self
	self.x = MathUtils:Lerp(from.x, to.x, t)
	self.y = MathUtils:Lerp(from.y, to.y, t)
	self.z = MathUtils:Lerp(from.z, to.z, t)
	return self
end


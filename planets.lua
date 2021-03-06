function initPlanets (numPlanets)
	planets = {}
	planetConnections = {}
	startingColonies = math.ceil(numPlanets / 2)
	for i=1, numPlanets do
		local sun = suns[randomIntegerBetween(1, tableSize(suns))]
		local planet = newPlanet(sun)
		if i == 1 then
			-- create player homeworld
			planet.isHomeWorld = true
			planet.startingColony = game.human.colony
			planet.maxSpores = 6
			game.human.homeWorld = planet
			game.human.selectedPlanet = planet
		elseif i <= startingColonies then
			-- create ai homeworlds
			planet.isHomeWorld = true
		end
		planet:initSpores()
		table.insert(planets, planet)
	end
end

function updatePlanets ()
	for _, planet in pairs(planets) do
		planet:update()
		if planet.isHomeWorld and planet ~= game.human.homeWorld and planet:onScreen() then
			game.flags.enemyHomeInView = true
		end
	end
end

function drawPlanets ()
	for _, planet in pairs(planets) do
		planet:drawOrbit()
	end
	
	for _, planetConnection in pairs(planetConnections) do
		planetConnection:draw()
	end
	
	for _, planet in pairs(planets) do
		planet:drawSporesOffPlanet()
	end
	
	for _, planet in pairs(planets) do
		planet:drawShadow()
		planet:drawSpores()
		planet:draw()
	end
end

function newPlanet (sun)
	local p = {}
	
	p.startingColony = newColony()
	p.maxSpores = randomIntegerBetween(3, 12)
	p.spores = {}
	p.sporesOffPlanet = {}
	p.shouldCleanupSpores = false
	p.sporeWidthAngle = 0
	
	p.connections = {}
	p.shouldUpdateConnections = false
	
	p.sun = sun
	
	p.radius = p.maxSpores * UNIT_RADIUS / PI
	p.rotationAngle = randomRealBetween(0, TAU)
	p.rotationVelocity = randomRealBetween(-0.5, 0.5)
	p.orbitRadius = p.sun:newOrbit()
	p.orbitAngle = randomRealBetween(0, TAU)
	p.orbitVelocity = randomRealBetween(PI/100, PI/20)
	p.location = newVector(math.cos(p.orbitAngle) * p.orbitRadius, math.sin(p.orbitAngle) * p.orbitRadius)
	p.location = vAdd(p.location, p.sun.location)
	
	p.isHomeWorld = false
	
	function p:initSpores ()
		if self.isHomeWorld then
			for i=1, self.maxSpores do
				table.insert(self.spores, newSpore(self, self.startingColony, i))
			end
		end
		self.radius = self.maxSpores * UNIT_RADIUS / PI
	end
	
	function p:update ()
		self.rotationAngle = (self.rotationAngle + (self.rotationVelocity / game.turn_time)) % TAU
		self.orbitAngle = self.orbitAngle + (self.orbitVelocity / game.turn_time)
		self.location = newVector(math.cos(self.orbitAngle) * self.orbitRadius,
															math.sin(self.orbitAngle) * self.orbitRadius)
		self.location = vAdd(self.location, self.sun.location)
		
		local sporeWidthSum = 0
		local sporesOnHomeworld = 0
		for _, spore in pairs(self.spores) do
			spore:update()
			if self.isHomeWorld and spore.colony == self.startingColony then sporesOnHomeworld = sporesOnHomeworld + 1 end
			sporeWidthSum = sporeWidthSum + spore.width
		end
		if self.isHomeWorld and sporesOnHomeworld == 0 then
			self.isHomeWorld = false
			if game.soundOn and self.startingColony ~= game.human.colony then
				homeWorldLossSound:setPitch(1*randomRealBetween(.9, 1.1))
				homeWorldLossSound:play()
			end
			game:checkGameOver()
		end
		self.sporeWidthAngle = TAU / sporeWidthSum

		for _, spore in pairs(self.sporesOffPlanet) do
			spore:update()
		end
		
		if self.shouldCleanupSpores then self:cleanupSpores() end
		if self.shouldUpdateConnections then self:updateConnections() end
	end
	
	function p:draw ()
		if self.isHomeWorld then
			self.startingColony:setToMyColor(150)
			love.graphics.setLineWidth(1)
			love.graphics.circle('line', self.location.x*game.zoom, self.location.y*game.zoom, (self.radius+UNIT_RADIUS*4)*game.zoom, SEGMENTS)
		end
		
		love.graphics.setColor(200, 200, 200)
		drawFilledCircle(self.location.x, self.location.y, self.radius)
		
		--love.graphics.setColor(0, 0, 0)
		--love.graphics.setFont(fontMessageSmallest)
		--love.graphics.print(self:countFriends(game.human.colony), self.location.x, self.location.y)
	end
	
	function p:drawOrbit ()
		love.graphics.setColor(255, 255, 255, 10)
		love.graphics.setLineWidth(1)
		love.graphics.circle('line', self.sun.location.x*game.zoom, self.sun.location.y*game.zoom, self.orbitRadius*game.zoom, SEGMENTS*2)
	end
	
	function p:drawShadow ()
		love.graphics.setColor(0, 0, 0, 20)
		drawFilledCircle(self.location.x, self.location.y, self.radius+1)
	end
	
	function p:drawSpores ()
		for _, spore in pairs(self.spores) do
			spore:draw()
		end
	end
	
	function p:drawSporesOffPlanet ()
		for _, spore in pairs(self.sporesOffPlanet) do
			spore:draw()
		end
	end
	
	function p:getSporeLocation (mySpore)
		local sporeAngle = self.rotationAngle + mySpore.rotationAngle
		for _, spore in pairs(self.spores) do
			if spore.position < mySpore.position then
				sporeAngle = sporeAngle + (self.sporeWidthAngle * spore.width)
			end
		end
		local d = self.radius + UNIT_RADIUS
		local v = newVector(self.location.x+math.cos(sporeAngle)*d, self.location.y+math.sin(sporeAngle)*d)
		return v
	end
	
	function p:updateConnections ()
		self.connections = {}
		for _, c in pairs(planetConnections) do
			if c.a == self then
				table.insert(self.connections, c.b)
			elseif c.b == self then
				table.insert(self.connections, c.a)
			end
		end
		self.shouldUpdateConnections = false
	end
	
	function p:isRoomAvailable ()
		return tableSize(self.spores) < self.maxSpores
	end
	
	function p:connectionWithRoom ()
		local connectionsWithRoom = {}
		for _, planet in pairs(self.connections) do
			if planet:isRoomAvailable() then
				table.insert(connectionsWithRoom, planet)
			end
		end
		return randomElement(connectionsWithRoom)
	end
	
	function p:listEnemies (friendlyColony)
		local enemies = {}
		for _, spore in pairs(self.spores) do
			if spore.state == 'ready' and spore.colony ~= friendlyColony then
				table.insert(enemies, spore)
			end
		end
		return enemies
	end
	
	function p:findEnemyLocally (friendlyColony)
		local enemies = self:listEnemies(friendlyColony)
		if enemies == {} then
			return nil
		else
			return randomElement(enemies)
		end
	end
	
	function p:findEnemyAbroad (friendlyColony)
		local enemies = {}
		for _, planet in pairs(self.connections) do
			appendToTable(enemies, planet:listEnemies(friendlyColony))
		end
		if enemies == {} then
			return nil
		else
			return randomElement(enemies)
		end
	end
	
	function p:countFriends (friendlyColony)
		local friendCount = 0
		for _, spore in pairs(self.spores) do
			if spore.state == 'ready' and spore.colony == friendlyColony then
				friendCount = friendCount + 1
			end
		end
		return friendCount
	end
	
	function p:findFriend (friendlyColony)
		local friends = {}
		for _, spore in pairs(self.spores) do
			if spore.state == 'ready' and spore.colony == friendlyColony then
				table.insert(friends, spore)
			end
		end
		return randomElement(friends)
	end
	
	function p:insertSpore (toPosition, newSpore)
		table.insert(self.spores, toPosition, newSpore)
		self:cleanupSpores()
	end
	
	function p:cleanupSpores ()
		local cleanSporeList = {}
		for _,spore in pairs(self.spores) do
			if spore.state == 'exploring' and spore.width == 0 then
				table.insert(self.sporesOffPlanet, spore)
			elseif spore.state ~= 'dead' and spore.planet == self then
				table.insert(cleanSporeList, spore)
			end
		end
		for i,spore in pairs(cleanSporeList) do
			spore.position = i
		end
		self.spores = cleanSporeList
		
		local cleanSporeOffPlanetList = {}
		for _,spore in pairs(self.sporesOffPlanet) do
			if spore.state ~= 'dead' and spore.planet == self then
				table.insert(cleanSporeOffPlanetList, spore)
			end
		end
		self.sporesOffPlanet = cleanSporeOffPlanetList
		
		self.shouldCleanupSpores = false
	end
	
	function p:onScreen (lenient)
		local pos = self.location
		local v = newVector(pos.x, pos.y)
		v = vMul(v, game.zoom)
		v = vAdd(v, game.offset)
		local w = love.graphics.getWidth()
		local h = love.graphics.getHeight()
		local isOnScreen = v.x > w*.2 and v.x < w*.8 and v.y > h*.2 and v.y < h*.8
		if lenient then
			isOnScreen = v.x > -10 and v.x < w+10 and v.y > -10 and v.y < h+10
		end
		return isOnScreen
	end
	
	return p
end
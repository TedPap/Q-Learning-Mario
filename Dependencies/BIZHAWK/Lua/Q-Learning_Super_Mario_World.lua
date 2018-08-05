if gameinfo.getromname() == "Super Mario World (USA)" then
	Filename = "DP1.state"
	ButtonNames = {
		"A",
		"B",
		"Down",
		"Right",
	}
end

BoxRadius = 6
InputSize = (BoxRadius*2+1)*(BoxRadius*2+1)

Inputs = InputSize+1
Outputs = #ButtonNames

TimeoutConstant = 20

learningRate = 0.5
discountFactor = 0.8
Temperature = 4

QValues = {}
SelectedMoves = {}
MoveProbabilities = {}

-- Boltzmann exploration probabilities initialization
for i=1, Outputs do
	MoveProbabilities[i] = 0
end

-- Q-Value initialization
for i=1, 700 do
	QValues[i] = {}
	for j=1, Outputs do
		QValues[i][1] = 30
		QValues[i][2] = 30
		QValues[i][3] = 0
		QValues[i][4] = 40
	end
	SelectedMoves[i] = 9
end


function getPositions()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		marioX = memory.read_s16_le(0x94)
		marioY = memory.read_s16_le(0x96)
		
		local layer1x = memory.read_s16_le(0x1A);
		local layer1y = memory.read_s16_le(0x1C);
		
		screenX = marioX-layer1x
		screenY = marioY-layer1y
	end
end


function getTile(dx, dy)
	if gameinfo.getromname() == "Super Mario World (USA)" then
		x = math.floor((marioX+dx+8)/16)
		y = math.floor((marioY+dy)/16)
		
		return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
	elseif gameinfo.getromname() == "Super Mario Bros." then
		local x = marioX + dx + 8
		local y = marioY + dy - 16
		local page = math.floor(x/256)%2

		local subx = math.floor((x%256)/16)
		local suby = math.floor((y - 32)/16)
		local addr = 0x500 + page*13*16+suby*16+subx
		
		if suby >= 13 or suby < 0 then
			return 0
		end
		
		if memory.readbyte(addr) ~= 0 then
			return 1
		else
			return 0
		end
	end
end


function getSprites()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		local sprites = {}
		for slot=0,11 do
			local status = memory.readbyte(0x14C8+slot)
			if status ~= 0 then
				spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
				spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
				sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey}
			end
		end		
		
		return sprites
	elseif gameinfo.getromname() == "Super Mario Bros." then
		local sprites = {}
		for slot=0,4 do
			local enemy = memory.readbyte(0xF+slot)
			if enemy ~= 0 then
				local ex = memory.readbyte(0x6E + slot)*0x100 + memory.readbyte(0x87+slot)
				local ey = memory.readbyte(0xCF + slot)+24
				sprites[#sprites+1] = {["x"]=ex,["y"]=ey}
			end
		end
		
		return sprites
	end
end


function getExtendedSprites()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		local extended = {}
		for slot=0,11 do
			local number = memory.readbyte(0x170B+slot)
			if number ~= 0 then
				spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
				spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
				extended[#extended+1] = {["x"]=spritex, ["y"]=spritey}
			end
		end		
		
		return extended
	elseif gameinfo.getromname() == "Super Mario Bros." then
		return {}
	end
end


function getInputs()
	getPositions()
	
	sprites = getSprites()
	extended = getExtendedSprites()
	
	local inputs = {}
	
	for dy=-BoxRadius*16,BoxRadius*16,16 do
		for dx=-BoxRadius*16,BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			
			tile = getTile(dx, dy)
			if tile == 1 and marioY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
			
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (marioX+dx))
				disty = math.abs(sprites[i]["y"] - (marioY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = -1
				end
			end

			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (marioX+dx))
				disty = math.abs(extended[i]["y"] - (marioY+dy))
				if distx < 8 and disty < 8 then
					inputs[#inputs] = -1
				end
			end
		end
	end
	
	return inputs
end


function newgame()
	local game = {}
	game.innovation = Outputs
	game.currentFrame = 0
	game.startTime = 0
	game.state = 1
	game.maxFitness = 0
	game.limit = -1
	game.stuck = 0

	
	return game
end


function maxQValueIndex()
	local maxQ = 0
	local maxQIndex = 8
	for j=1, Outputs do
		if QValues[game.state][j] > maxQ then
			maxQ = QValues[game.state][j]
			maxQIndex = j
		end
	end
	return maxQIndex
end


function BoltzmannExploration()
	local sum = 0
	for j=1, Outputs do
		sum = sum + math.exp((QValues[game.state][j]) / Temperature)
	end

	for j=1, Outputs do
		MoveProbabilities[j] = (math.exp((QValues[game.state][j]) / Temperature) / sum)
	end
end


function selectNextMove()
	
	local outputs = {}
	local rand = math.random(4)
	for o=1,Outputs do
		local button = "P1 " .. ButtonNames[o]
		outputs[button] = false
	end

	-- Boltzmann Exploration
	BoltzmannExploration()
	local p = math.random();
	local cumulativeProbability = 0.0;
	for j=1, Outputs do
		cumulativeProbability = cumulativeProbability + MoveProbabilities[j]

		if (p <= cumulativeProbability) then
			local tmp_button = "P1 " .. ButtonNames[j]
			outputs[tmp_button] = true
			SelectedMoves[game.state] = j
			break
		end
	end

	-- Greedy selection
	-- local nextMove = maxQValueIndex()
	-- local tmp_button = "P1 " .. ButtonNames[nextMove]
	-- outputs[tmp_button] = true
	-- SelectedMoves[game.state] = nextMove
	
	return outputs
end


function initializegame()
	game = newgame()
	initializeRun()
end


function clearJoypad()
	controller = {}
	for b = 1,#ButtonNames do
		controller["P1 " .. ButtonNames[b]] = false
	end
	joypad.set(controller)
end


function initializeRun()
	savestate.load(Filename);
	rightmost = 0
	game.currentFrame = 0
	game.startTime = os.time()
	game.startTime = 0
	game.state = 1
	timeout = TimeoutConstant
	clearJoypad()
	
	normalizeNextMove()
end


function normalizeNextMove()

	controller = selectNextMove()
	
	if controller["P1 Left"] and controller["P1 Right"] then
		controller["P1 Left"] = false
		controller["P1 Right"] = false
	end
	if controller["P1 Up"] and controller["P1 Down"] then
		controller["P1 Up"] = false
		controller["P1 Down"] = false
	end

	joypad.set(controller)
end


function maxQValue(index)
	local maxQ = 0
	for j=1, Outputs do
		if QValues[index + 1][j] > maxQ then
			maxQ = QValues[index + 1][j]
		end
	end
	return maxQ
end


function QValuesUpdate(fitness)

	local i = 1
	if game.state > 7 and fitness < 1000 then
		for i=1, game.state - 5 do
			local j = SelectedMoves[i]
			local tmp = QValues[i][j]
			local reward = fitness
			QValues[i][j] = tmp + learningRate * (reward + discountFactor *(maxQValue(game.state)) - tmp )
			if QValues[i][j] > 100000000 then
				QValues[i][j] = 100000000
			end
		end
		i = game.state - 3
		local j = SelectedMoves[i]
		local tmp = QValues[i][j]
		local reward = -100
		QValues[i][j] = tmp + learningRate * (reward - tmp )
		if QValues[i][j] < 0 then
			QValues[i][j] = 0
		end
		i = game.state - 4
		local j = SelectedMoves[i]
		local tmp = QValues[i][j]
		local reward = -50
		QValues[i][j] = tmp + learningRate * (reward - tmp )
		if QValues[i][j] < 0 then
			QValues[i][j] = 0
		end
	else
		for i=1, game.state - 3 do
			local j = SelectedMoves[i]
			local tmp = QValues[i][j]
			local reward = fitness
			QValues[i][j] = tmp + learningRate * (reward + discountFactor *(maxQValue(game.state)) - tmp )
			if QValues[i][j] > 100000000 then
				QValues[i][j] = 100000000
			end
		end
	end

	-- Wipe faulty knowledge if mario is stuck somewhere
	if game.limit == game.state then
		game.stuck = game.stuck + 1
	
		if game.stuck > 7 then
			game.stuck = 0
			local count  = 0
			while count < game.state-1 and count < 7 do
				count = count + 1
			end
			console.writeline("count " ..count)
			for i=game.state-count, game.state do
				for j=1,Outputs do
					console.writeline("i " ..i)
					console.writeline("j " ..j)
					console.writeline("Q " ..QValues[i][j])
					-- QValues[i][j] = QValues[i][j] - math.random(1, QValues[i][j]+2)
					QValues[i][j] = math.random(1, 40)
					if QValues[i][j] < 0 then
						QValues[i][j] = 0
					end
				end
			end
		end
	end
	game.limit = game.state

end

if game == nil then
	initializegame()
end

-- FILE OPS --

function onExit()
	forms.destroy(form)
end

-- FILE OPS --

event.onexit(onExit)

form = forms.newform(200, 500, "Fitness")
maxFitnessLabel = forms.label(form, "Max Fitness: " .. math.floor(game.maxFitness), 5, 10)
QValuesTitleLabel = forms.label(form, "Last state: " .. game.state .. " Q-Values", 5, 50)
QValuesLabel1 = forms.label(form, "QValue[1]: " .. (QValues[game.state][1]), 5, 90)
QValuesLabel2 = forms.label(form, "QValue[2]: " .. (QValues[game.state][2]), 5, 130)
QValuesLabel3 = forms.label(form, "QValue[3]: " .. (QValues[game.state][3]), 5, 170)
QValuesLabel4 = forms.label(form, "QValue[4]: " .. (QValues[game.state][4]), 5, 210)
restartButton = forms.button(form, "Restart", initializegame, 5, 400)
hideBanner = forms.checkbox(form, "Hide Banner", 5, 440)


while true do
	local backgroundColor = 0xD0FFFFFF
	local fitness = 0
	if not forms.ischecked(hideBanner) then
		gui.drawBox(0, 0, 300, 26, backgroundColor, backgroundColor)
	end
	
	-- Advance state of Q-learning
	-- if os.difftime(os.time(), game.startTime) >= 1 then
	-- 	game.state = game.state + 1
	-- 	game.startTime = os.time()

	-- 	-- Choose next move
	-- 	normalizeNextMove()
	-- end

	if game.currentFrame - game.startTime >= 21 then
		game.state = game.state + 1
		game.startTime = game.currentFrame

		-- Choose next move
		normalizeNextMove()
	end

	-- Set agent's output
	joypad.set(controller)

	-- Check if mario has moved forward. If true reset timeout
	getPositions()
	if marioX > rightmost then
		rightmost = marioX
		timeout = TimeoutConstant
	end
	
	fitness = math.floor(rightmost / 8)
	timeout = timeout - 1
	
	
	-- local timeoutBonus = game.currentFrame / 8
	local timeoutBonus = 60
	if timeout + timeoutBonus <= 0 then

		-- Detect if end of level
		if gameinfo.getromname() == "Super Mario World (USA)" and rightmost > 4816 then
			fitness = fitness + 1000
		end

		if fitness == 0 then
			fitness = -1
		end
		
		-- Set maxFitness
		if fitness > game.maxFitness then
			game.maxFitness = fitness
			forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(game.maxFitness))
		end

		-- Update Q-Values
		QValuesUpdate(fitness)

		-- Anneal Temperature
		if Temperature > 2 then
			Temperature = Temperature - 0.001
		end

		-- I/O
		forms.settext(QValuesTitleLabel, "Last state: " .. game.state - 3 .. " Q-Values")
		forms.settext(QValuesLabel1, "QValue[1]: " .. math.floor((QValues[game.state-3][1])))
		forms.settext(QValuesLabel2, "QValue[2]: " .. math.floor((QValues[game.state-3][2])))
		forms.settext(QValuesLabel3, "QValue[3]: " .. math.floor((QValues[game.state-3][3])))
		forms.settext(QValuesLabel4, "QValue[4]: " .. math.floor((QValues[game.state-3][4])))
		console.clear()

		initializeRun()
	end

	local measured = 0
	local total = 0
	if not forms.ischecked(hideBanner) then
		gui.drawText(0, 12, "F: " .. fitness, 0xFF000000, 11)
		gui.drawText(50, 12, "S: " .. game.state, 0xFF000000, 11)
		gui.drawText(100, 12, "M: " .. SelectedMoves[game.state], 0xFF000000, 11)
		gui.drawText(150, 12, "T: " .. Temperature, 0xFF000000, 11)
	end
		
	game.currentFrame = game.currentFrame + 1

	emu.frameadvance();
end
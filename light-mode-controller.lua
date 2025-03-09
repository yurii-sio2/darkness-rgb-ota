dofile(activeFolder .. "light-sensor.lua");
dofile(activeFolder .. "rgb-led-driver.lua")

local MODE_RANDOM_BY_MOVE = 0
local MODE_WHITE_BY_MOVE = 1
local MODE_RANDOM_INFINITE = 2
local MODE_WHITE_INFINITE = 3

local countBackTimer
local lightLevelTimer
-- local noMotionTimer

local ledDriver
local lightSensor

local currentMode

local isStartingCountBackTimer = 0

local totalMotionSensors = 1
local motionSensorsSignaled = 0

LightModeController = {}
LightModeController.__index = LightModeController

function LightModeController.init(ledsCnf, lighSensorCnf)
    local self = setmetatable({}, LightModeController)

	onboardLedPin = 4
	gpio.mode(onboardLedPin, gpio.OUTPUT)
	gpio.write(onboardLedPin, gpio.LOW)      -- inveted pin. turn on led

    self.ledsCnf = ledsCnf
    ledDriver = LedDriver.init(self.ledsCnf.pinRed, 
                        self.ledsCnf.pinGreen, self.ledsCnf.pinBlue, 
                        self.ledsCnf.changeColorOncePerSeconds,
                        self.ledsCnf.pwmFreequency)
    
    lightSensor = LightSensor.init(lighSensorCnf.lowerThreshold, 
                        lighSensorCnf.upperThreshold)
                        
	currentMode = MODE_RANDOM_BY_MOVE
	
	self:setupPins()
	self:setupTimers()
	self:setupMoveSensorTrigger()
	    
	gpio.write(onboardLedPin, gpio.HIGH) -- inveted pin. turn off led
    return self
end

function LightModeController.start(self)
	if(currentMode == MODE_RANDOM_BY_MOVE) then
		ledDriver:setModeRandom()
		moveDetectedPin1(gpio.HIGH, 0)
		moveDetectedPin1(gpio.LOW, 1)
	elseif(currentMode == MODE_WHITE_BY_MOVE) then
		ledDriver:setModeWhite()
		moveDetectedPin1(gpio.HIGH, 0)
		moveDetectedPin1(gpio.LOW, 1)
	elseif(currentMode == MODE_RANDOM_INFINITE) then
		ledDriver:setModeRandom()
		ledDriver:on()
	elseif(currentMode == MODE_WHITE_INFINITE) then
		ledDriver:setModeWhite()
		ledDriver:on()
	end
end

function LightModeController.setupPins(self)
	gpio.mode(moveSensorPin1, gpio.INT)
    totalMotionSensors = 1
    if(moveSensorPin2 > -1) then
	    gpio.mode(moveSensorPin2, gpio.INT)
        totalMotionSensors = 2
    end

	gpio.mode(self.ledsCnf.pinRed, gpio.OUTPUT)
	gpio.mode(self.ledsCnf.pinGreen, gpio.OUTPUT)
	gpio.mode(self.ledsCnf.pinBlue, gpio.OUTPUT)

	gpio.write(self.ledsCnf.pinRed, gpio.LOW)
	gpio.write(self.ledsCnf.pinGreen, gpio.LOW)
	gpio.write(self.ledsCnf.pinBlue, gpio.LOW)
end

function LightModeController.setupTimers(self)
	-- self.setupNoMotionTimer()
	self:setupCountBackTimer()
	self:setupLightLevelTimer()
end

--[[
function LightModeController.setupNoMotionTimer()
	noMotionTimer = tmr.create()
	noMotionTimer:register(
		60 * 1000,
		tmr.ALARM_SEMI,
		function()
			print("No motion for a long period. Stopping light level check timer.")
			lightLevelCheckTimerStop()
		end
	)
end
]]

function LightModeController.setupCountBackTimer(self)
	countBackTimer = tmr.create()
	countBackTimer:register(
		1000 * self.ledsCnf.ledOnTimeoutSec,
		tmr.ALARM_SEMI,
		function()
			print("Tutn off led")
			countBackTimer:stop()
			ledDriver:off()
		end
	)
end

local function turnOnLedAndRestartTurnOffTimer()

	if(isStartingCountBackTimer == 1) then
		return
	end
	
	isStartingCountBackTimer = 1
	
    local isRunning, mode = countBackTimer:state()

    if(isRunning) then
        print("Countback timer is running. Stopping")
        countBackTimer:stop()
    else
        --if(lightSensor:getState() == 0) then
            print("Turn on led")
            ledDriver:on()
        --else
        --    print("Do not turn led on. It's to bright.")
        --    return
       -- end
    end

    print("Starting countback timer")
    countBackTimer:start()
	
	isStartingCountBackTimer = 0
end

function LightModeController.setupLightLevelTimer()

	lightLevelTimer = tmr.create()
	lightLevelTimer:alarm(
		300,
		tmr.ALARM_AUTO, 
		function()
            -- print("motionSensorsSignaled = " .. motionSensorsSignaled)

            -- correct possibe errors
            if(motionSensorsSignaled > totalMotionSensors) then
                motionSensorsSignaled = totalMotionSensors
            end
            if(motionSensorsSignaled < 0) then
                motionSensorsSignaled = 0
            end
            
			if(motionSensorsSignaled == 0) then
				return
			end

            local isCountBackTimerRunning, mode = countBackTimer:state()
            if(isCountBackTimerRunning) then
                -- if countBackTimer is running, then leds are ON now
                -- we need to restart countBackTimer
                turnOnLedAndRestartTurnOffTimer()
            else
                -- if countBackTimer is NOT running, then leds are OFF
                -- we need to check for light level
                local lightState = lightSensor:getState()
                print("light state check res: " .. lightState)
                if(lightState == 0) then
                    turnOnLedAndRestartTurnOffTimer()
                end
            end
		end
	)

end

--[[
function lightLevelCheckTimerStop()
    lightLevelTimer:stop()
end
]]

--[[
local function noMotionTimerStart()
    local isRunning, mode = noMotionTimer:state()

    if(isRunning) then
        noMotionTimer:stop()
    end
    noMotionTimer:start()
end
]]

function LightModeController.setupMoveSensorTrigger(self)
    print('init motion sensons listeners')
    gpio.trig(moveSensorPin1, 'both', moveDetectedPin1)
    if(moveSensorPin2 > -1) then
        gpio.trig(moveSensorPin2, 'both', moveDetectedPin2)
    end
end

function moveDetectedPin1(level, time, eventcount)
    print("move sensor 1 changed to " .. level)
	moveDetected(level)
end

function moveDetectedPin2(level, time, eventcount)
    print("move sensor 2 changed to " .. level)
	moveDetected(level)
end

function moveDetected(level)
	if(currentMode == MODE_RANDOM_BY_MOVE or currentMode == MODE_WHITE_BY_MOVE) then
		print("move detected: level = " .. level)
		if(level == gpio.HIGH) then
            motionSensorsSignaled = motionSensorsSignaled + 1
			--[[
			local isRunning, mode = countBackTimer:state()
			if(not isRunning) then
				-- print("(re)start light level timer")
				print("waiting for low light")
				-- lightLevelCheckTimerStart()
			-- else
			--	turnOnLedAndRestartTurnOffTimer()
			end
            ]]
		else
			print("no motion")
            motionSensorsSignaled = motionSensorsSignaled - 1
			-- noMotionTimerStart()
		end
	end
end

function LightModeController.setModeRandomByMove(self)
    currentMode = MODE_RANDOM_BY_MOVE
    ledDriver:setModeRandom()
end

function LightModeController.setModeWhiteByMove(self)
    currentMode = MODE_WHITE_BY_MOVE
    ledDriver:setModeWhite()
end


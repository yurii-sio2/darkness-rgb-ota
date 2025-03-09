
local MODE_RANDOM = 0
local MODE_WHITE = 1

LedDriver = {}
LedDriver.__index = LedDriver


function LedDriver.init(pinRed, pinGreen, pinBlue, changeColorOncePerSeconds, pwmFreequency)
    local self = setmetatable({}, LedDriver)
    self.pinRed = pinRed
    self.pinGreen = pinGreen
    self.pinBlue = pinBlue
    
    self.freeq = pwmFreequency
    self.maxDuty = 1023
    self.maxTotalDuty = 1023
    self.smoothTimeMSec = 4000
    self.colorChangeTimeMSec = 6000

    self.changeColorOncePerSeconds = changeColorOncePerSeconds

    self.smoothTimer = tmr.create()
    self.colorChangeTimer = tmr.create()
    self:registerColorChangeTimer()

    pwm.setup(self.pinRed, self.freeq, 0)
    pwm.setup(self.pinGreen, self.freeq, 0)
    pwm.setup(self.pinBlue, self.freeq, 0)
    
    gpio.write(self.pinRed, gpio.LOW)
    gpio.write(self.pinGreen, gpio.LOW)
    gpio.write(self.pinBlue, gpio.LOW)

    self.lastDutyRed = 0;
    self.lastDutyGreen = 0;
    self.lastDutyBlue = 0;
	
	self.currentMode = MODE_RANDOM
    
    return self
end

function LedDriver.registerColorChangeTimer(self)
    self.colorChangeTimer:register(
        self.changeColorOncePerSeconds * 1000,
        tmr.ALARM_AUTO, 
        function()
            print("Changing color")
            local dutyRed, dutyGreen, dutyBlue = 
                self:getColor()
            local oldSmoothTime = self.smoothTimeMSec
            self.smoothTimeMSec = self.colorChangeTimeMSec
            
            self:smoothChange(self.lastDutyRed, self.lastDutyGreen, 
                self.lastDutyBlue, dutyRed, dutyGreen, dutyBlue)

            self.smoothTimeMSec = oldSmoothTime
            --[[
            self.lastDutyRed = dutyRed
            self.lastDutyGreen = dutyGreen
            self.lastDutyBlue = dutyBlue]]
        end
    )
end


function LedDriver.on(self)
    print("ON")
    self.lastDutyRed, self.lastDutyGreen, self.lastDutyBlue = 
        self:getColor()
        
    self:smoothChange(0, 0, 0,
        self.lastDutyRed, self.lastDutyGreen, self.lastDutyBlue)

    if(self.currentMode == MODE_RANDOM) then
        self.colorChangeTimer:start()
    end
end

function LedDriver.smoothChange(self, redStart, greenStart, blueStart,
                            redStop, greenStop, blueStop)

    self:setPwmDuties(redStart, greenStart, blueStart)
    
    pwm.start(self.pinRed)
    pwm.start(self.pinGreen)
    pwm.start(self.pinBlue)

    local timerFreequency = 30
    local precisionMultiplier = 1000
    local stepsCount = math.floor(self.smoothTimeMSec / timerFreequency)
    local currentStep = 0
    local redDeltaPerStep = (redStop - redStart) * precisionMultiplier / stepsCount
    local greenDeltaPerStep = (greenStop - greenStart) * precisionMultiplier / stepsCount
    local blueDeltaPerStep = (blueStop - blueStart) * precisionMultiplier / stepsCount

    -- print(stepsCount, self.smoothTimeMSec, timerFreequency)
    -- print(redStart, redStop, redDeltaPerStep)
    -- print(greenStart, greenStop, greenDeltaPerStep)
    -- print(blueStart, blueStop, blueDeltaPerStep)
    
    self.smoothTimer:alarm(
        timerFreequency,
        tmr.ALARM_AUTO, 
        function()
            currentStep = currentStep + 1
            local redCurrent = math.floor(redStart + redDeltaPerStep * currentStep / precisionMultiplier)
            local greenCurrent = math.floor(greenStart + greenDeltaPerStep * currentStep / precisionMultiplier)
            local blueCurrent = math.floor(blueStart + blueDeltaPerStep * currentStep / precisionMultiplier)
            
            if(redCurrent > self.maxDuty) then redCurrent = self.maxDuty end
            if(greenCurrent > self.maxDuty) then greenCurrent = self.maxDuty end
            if(blueCurrent > self.maxDuty) then blueCurrent = self.maxDuty end

            if(redCurrent < 0) then redCurrent = 0 end
            if(greenCurrent < 0) then greenCurrent = 0 end
            if(blueCurrent < 0) then blueCurrent = 0 end

            if(currentStep > stepsCount) then
                self.smoothTimer:stop()
                -- print("!!!", redCurrent, greenCurrent, blueCurrent)

                redCurrent = redStop
                greenCurrent = greenStop
                blueCurrent = blueStop

                if(redStop == 0) then pwm.stop(self.pinRed) end
                if(greenStop == 0) then pwm.stop(self.pinGreen) end
                if(blueStop == 0) then pwm.stop(self.pinBlue) end
            end

            self.lastDutyRed = redCurrent
            self.lastDutyGreen = greenCurrent
            self.lastDutyBlue = blueCurrent
            self:setPwmDuties(redCurrent, greenCurrent, blueCurrent)
        end
    )
end

function LedDriver.setPwmDuties(self, redDuty, greenDuty, blueDuty)
    pwm.setduty(self.pinRed, redDuty)
    pwm.setduty(self.pinGreen, greenDuty)
    pwm.setduty(self.pinBlue, blueDuty)
end

function LedDriver.off(self)
    print("OFF")
    self.smoothTimer:stop()
    self.colorChangeTimer:stop()
    self:smoothChange(self.lastDutyRed, self.lastDutyGreen, self.lastDutyBlue, 
        0, 0, 0)
end

function LedDriver.getColor(self)
	if(self.currentMode == MODE_WHITE) then
		return 1023, 370, 190
	else -- MODE_RANDOM
		variant = node.random(1, 3)
		if(variant == 1) then
			red, green, blue = self:getRandomColors()
		elseif(variant == 2) then
			green, blue, red = self:getRandomColors()
		else
			blue, red, green = self:getRandomColors()
		end
        print(red, green, blue, red + green + blue)
        return red, green, blue
	end
end

function LedDriver.getRandomColors(self)
    c3 = 0
    c1 = node.random(0, self.maxDuty)
    if(c1 > self.maxTotalDuty) then
        c1 = self.maxTotalDuty
    end
    
    c2 = node.random(0, self.maxDuty)
    if(c1 + c2 >= self.maxTotalDuty) then
        c2 = self.maxTotalDuty - c1
    else
        c3 = node.random(0, self.maxDuty)
        if(c1 + c2 + c3 >= self.maxTotalDuty) then
            c3 = self.maxTotalDuty - c1 - c2
        end
    end

    return c1, c2, c3
end

function LedDriver.setModeRandom(self)
	self.currentMode = MODE_RANDOM
    -- self.colorChangeTimer:start()
end

function LedDriver.setModeWhite(self)
	self.currentMode = MODE_WHITE
    self.colorChangeTimer:stop()
    --[[
    local dutyRed, dutyGreen, dutyBlue = 
                self:getColor()
    self:smoothChange(self.lastDutyRed, self.lastDutyGreen, 
                    self.lastDutyBlue, dutyRed, dutyGreen, dutyBlue)
    ]]
end

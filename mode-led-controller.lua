-- Controlling of the led that displays current working mode
WorkingModeLed = {}
WorkingModeLed.__index = WorkingModeLed

local this

local MODE_STARTING = 0
local MODE_WORKING = 1
local MODE_WAITING = 2

local modeWorkingTimer = tmr.create()
local currentWorkLedDuty = 0
local workLedChangeDirection = 1

local modeStartingDutyChangeFreeq = 40

local modeWorkingOffTimeMs = 3000
local modeWorkingOnTimeMs = 50

local modeWaitingOffTimeMs = 1000
local modeWaitingOnTimeMs = 1000

local currentModeOffTimeMs = 1000
local currentModeOnTimeMs = 1000
local currentModeIsLedOn = false



local prevTimeSeconds = 0
local prevTimeMs = 0

modeWorkingTimer:register(
    11,
    tmr.ALARM_AUTO, 
    function()
        -- print("in alarm")
        if(this.currentMode == MODE_STARTING) then
            local msElapsed = this:getTimeElapsedMs()
            -- print("mode STARTING, ", msElapsed)
            if(msElapsed >= modeStartingDutyChangeFreeq) then
                -- print("Change duty, ", msElapsed)
                this:resetTimeElapsed()
                
                if(workLedChangeDirection == 1) then
                    currentWorkLedDuty = currentWorkLedDuty + 50
                else
                    currentWorkLedDuty = currentWorkLedDuty - 50
                end
                if(currentWorkLedDuty >= 1000) then
                    currentWorkLedDuty = 1000
                    workLedChangeDirection = 0
                end
                if(currentWorkLedDuty <= 0) then
                    currentWorkLedDuty = 0
                    workLedChangeDirection = 1
                end
        
                pwm.setduty(this.ledPin, currentWorkLedDuty)
            end
        elseif(this.currentMode == MODE_WORKING or 
            this.currentMode == MODE_WAITING) then
            local msElapsed = this:getTimeElapsedMs()
            if(currentModeIsLedOn) then
                if(msElapsed >= currentModeOnTimeMs) then
                    -- print("off", msElapsed)
                    this:resetTimeElapsed()
                    gpio.write(this.ledPin, gpio.LOW);
                    currentModeIsLedOn = false
                end
            else
                if(msElapsed >= currentModeOffTimeMs) then
                    -- print("on", msElapsed)
                    this:resetTimeElapsed()
                    gpio.write(this.ledPin, gpio.HIGH);
                    currentModeIsLedOn = true
                end
            end
        end
    end
)

function WorkingModeLed.init(ledPin)
    local self = setmetatable({}, WorkingModeLed)
    
    rtctime.set(0, 0)
    
    self.currentMode = nil
    self.ledPin = ledPin
    gpio.mode(self.ledPin, gpio.OUTPUT)
    gpio.write(self.ledPin, gpio.LOW)
    pwm.setup(self.ledPin, 100, currentWorkLedDuty)
    -- self:setModeWaiting()
    modeWorkingTimer:start()
    this = self
    return self
end

function WorkingModeLed.setModeStarting(self)
    if(self.currentMode == MODE_STARTING) then
        return
    end
    print("setting mode MODE_STARTING")
    self.currentMode = MODE_STARTING
    
    currentWorkLedDuty = 0
    workLedChangeDirection = 1
    
    pwm.start(self.ledPin)
end
function WorkingModeLed.setModeWorking(self)
    if(self.currentMode == MODE_WORKING) then
        return
    end
    print("setting mode MODE_WORKING")
    self.currentMode = MODE_WORKING

    currentModeOffTimeMs = modeWorkingOffTimeMs
    currentModeOnTimeMs = modeWorkingOnTimeMs
    currentModeIsLedOn = false

    pwm.close(self.ledPin)
    gpio.write(self.ledPin, gpio.LOW)
end
function WorkingModeLed.setModeWaiting(self)
    if(self.currentMode == MODE_WAITING) then
        return
    end
    print("setting mode MODE_WAITING")
    self.currentMode = MODE_WAITING
    
    currentModeOffTimeMs = modeWaitingOffTimeMs
    currentModeOnTimeMs = modeWaitingOnTimeMs
    currentModeIsLedOn = false

    pwm.close(self.ledPin)
    gpio.write(self.ledPin, gpio.LOW)
end

function WorkingModeLed.getTimeElapsedMs(self)
    local seconds, ms = rtctime.get()
    
    return ((seconds - prevTimeSeconds) * 1000000 + ms - prevTimeMs) / 1000
end

function WorkingModeLed.resetTimeElapsed(self)
    local seconds, ms = rtctime.get()
    prevTimeSeconds = seconds
    prevTimeMs = ms
end

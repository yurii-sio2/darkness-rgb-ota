LightSensor = {}
LightSensor.__index = LightSensor


function LightSensor.init(lowerThreshold, upperThreshold)
    local self = setmetatable({}, LightSensor)
    self.lowerThreshold = lowerThreshold
    self.upperThreshold = upperThreshold
    self.currentState = 0
    self.prevValue = 0
    return self
end

function LightSensor.getState(self)
    local value = adc.read(0)
    print("light sensor value: " .. value)
    if(self.prevValue < self.upperThreshold and 
        value >= self.upperThreshold) then
        self.currentState = 1
    elseif(self.prevValue > self.lowerThreshold and 
        value <= self.lowerThreshold) then
        self.currentState = 0
    end
    self.prevValue = value
    return self.currentState
end

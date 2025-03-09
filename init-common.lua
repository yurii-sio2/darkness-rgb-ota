local startTimer = tmr.create()

moveSensorPin1 = 1     -- GPIO5
moveSensorPin2 = (sensors_count == 1) and -1 or 0		-- use value 0 (GPIO16) for 2-nd sensor

stopButtonPin = 2     -- GPIO4
onboardLedPin = 4
workingModeLedPin = 8        -- GPIO15

dofile(activeFolder .. "mode-led-controller.lua")
local workingModeLed = WorkingModeLed.init(workingModeLedPin)
workingModeLed:setModeStarting()

function startup()
    print('in startup')
    startTimer:stop()

    workingModeLed:setModeWorking()
    dofile(activeFolder .. "start-program.lua");
end

gpio.mode(stopButtonPin, gpio.INPUT)
gpio.write(stopButtonPin, gpio.HIGH)

gpio.mode(onboardLedPin, gpio.OUTPUT)
local startupDelaySeconds = 9
local ledBlinkSwitchMs = 100
local ledBlinkSwitchesCount = startupDelaySeconds * 1000 / ledBlinkSwitchMs;
local ledBlinkedCount = 0

local isNotStopped = gpio.HIGH

local isOn = false

startTimer:alarm(
    ledBlinkSwitchMs,
    tmr.ALARM_AUTO, 
    function()
        if(isOn) then
            gpio.write(onboardLedPin, gpio.HIGH)
        else
            gpio.write(onboardLedPin, gpio.LOW)
        end
        isOn = not isOn
        ledBlinkedCount = ledBlinkedCount + 1
        if(ledBlinkedCount >= ledBlinkSwitchesCount and
            isNotStopped == gpio.HIGH) then
            startTimer:stop()
            if file.open('debug.lua','r') then
                print( 'debug mode is on')
                file.close()
            
                dofile(activeFolder .. "debug.lua")
            else
                startup()
			end
        else
            if(isNotStopped == gpio.LOW) then
                workingModeLed:setModeWaiting()
                -- print("stopped")
            else
                isNotStopped = gpio.read(stopButtonPin)
                if(isNotStopped == gpio.LOW) then
                    startTimer:stop()
                    ledBlinkSwitchMs = 1000
                    startTimer:interval(ledBlinkSwitchMs)
                    startTimer:start()
                    workingModeLed:setModeWaiting()
                    -- gpio.write(onboardLedPin, gpio.LOW)    -- turn on onboard led (pin has inverted value)
                    print("stopped")
                end
            end
        end
    end
)

startTimer:start()

print("init file executed")


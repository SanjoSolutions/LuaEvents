Events = {}

local frame = CreateFrame('Frame')
local isUsed = false

function Events.waitForOneOfEventsAndCondition(eventsToWaitFor, condition, timeout)
    if isUsed then
        error('Events system is already used.')
    end

    isUsed = true

    local thread = coroutine.running()

    local timer = nil

    local function finish(wasSuccessful, event, ...)
        if timer and not timer:IsCancelled() then
            timer:Cancel()
        end

        frame:UnregisterAllEvents()
        frame:SetScript('OnEvent', nil)

        isUsed = false

        resumeWithShowingError(thread, wasSuccessful, event, ...)
    end

    frame:SetScript('OnEvent', function(self, event, ...)
        if condition(self, event, ...) then
            finish(true, event, ...)
        end
    end)

    for _, event in ipairs(eventsToWaitFor) do
        frame:RegisterEvent(event)
    end

    if timeout then
        timer = C_Timer.NewTimer(timeout, function ()
            finish(false)
        end)
    end

    return coroutine.yield()
end

function Events.waitForOneOfEvents(eventsToWaitFor, timeout)
    return Events.waitForOneOfEventsAndCondition(eventsToWaitFor, Function.alwaysTrue, timeout)
end

function Events.waitForEventCondition(eventToWaitFor, condition, timeout)
    return Events.waitForOneOfEventsAndCondition({eventToWaitFor}, condition, timeout)
end

function Events.waitForEvent(eventToWaitFor, timeout)
    return Events.waitForEventCondition(eventToWaitFor, Function.alwaysTrue, timeout)
end
local addOnName = 'Events'
local version = '2.0.0'

if _G.Library then
  if not Library.isRegistered(addOnName, version) then
    local Function = Library.retrieve('Function', '^2.0.0')
    local Set = Library.retrieve('Set', '^1.1.0')
    local Coroutine = Library.retrieve('Coroutine', '^2.0.0')
    local Object = Library.retrieve('Object', '^1.1.0')
    local Array = Library.retrieve('Array', '^2.0.0')

    --- @class Events
    local Events = {}

    local _ = {}

    local frame = nil
    local entries = {}
    local registeredEvents = {}

    local function finish(entry, wasSuccessful, event, ...)
      _.removeEntry(entry)

      Coroutine.resumeWithShowingError(entry.thread, wasSuccessful, event, ...)
    end

    function _.removeEntry(entry)
      _.cleanUpEntry(entry)

      if Object.isEmpty(registeredEvents) then
        frame:SetScript('OnEvent', nil)
      end
    end

    function _.cleanUpEntry(entry)
      _.cancelTimerOfEntry(entry)
      _.removeRegisteredEventsOfEntry(entry)
      _.cleanUpRegisteredEvents()
      Array.removeFirstOccurence(entries, entry)
    end

    function _.cancelTimerOfEntry(entry)
      if entry.timer and not entry.timer:IsCancelled() then
        entry.timer:Cancel()
      end
    end

    function _.removeRegisteredEventsOfEntry(entry)
      for event in Set.iterator(entry.eventsToWaitFor or entry.eventsToListenTo) do
        Set.remove(registeredEvents[event], entry)
      end
    end

    function _.cleanUpRegisteredEvents()
      for event, registrations in pairs(registeredEvents) do
        if Set.isEmpty(registrations) then
          frame:UnregisterEvent(event)
          Object.remove(registeredEvents, event)
        end
      end
    end

    function Events.listenForEvent(event, callback)
      local entry = {
        eventsToListenTo = Set.create({ event }),
        callback = callback,
        thread = coroutine.running()
      }

      _.addEntry(entry)

      return {
        stopListening = function()
          _.removeEntry(entry)
        end
      }
    end

    function Events.waitForOneOfEventsAndCondition(eventsToWaitFor, condition, timeout)
      local entry = {
        eventsToWaitFor = Set.create(eventsToWaitFor),
        condition = condition,
        timeout = timeout,
        timer = nil,
        thread = coroutine.running()
      }

      _.addEntry(entry)

      return coroutine.yield()
    end

    function _.addEntry(entry)
      table.insert(entries, entry)

      if not frame then
        frame = CreateFrame('Frame')
      end

      if not frame:GetScript('OnEvent') then
        frame:SetScript('OnEvent', function(self, event, ...)
          for _, entry in ipairs(entries) do
            if entry.eventsToWaitFor then
              if Set.contains(entry.eventsToWaitFor, event) and entry.condition(self, event, ...) then
                if entry.duration then
                  if entry.timer2 then
                    entry.timer2:Cancel()
                    entry.timer2 = nil
                  end
                  local args = { ... }
                  entry.timer2 = C_Timer.NewTimer(entry.duration, function()
                    finish(entry, true, event, unpack(args))
                  end)
                else
                  finish(entry, true, event, ...)
                end
              end
            elseif entry.eventsToListenTo then
              if Set.contains(entry.eventsToListenTo, event) then
                entry.callback(event, ...)
              end
            end
          end
        end)
      end

      for event in Set.iterator(entry.eventsToWaitFor or entry.eventsToListenTo) do
        frame:RegisterEvent(event)
        if not registeredEvents[event] then
          registeredEvents[event] = Set.create()
        end
        Set.add(registeredEvents[event], entry)
      end

      if entry.timeout then
        entry.timer = C_Timer.NewTimer(entry.timeout, function()
          finish(entry, false)
        end)
      end
    end

    function Events.waitForOneOfEvents(eventsToWaitFor, timeout)
      return Events.waitForOneOfEventsAndCondition(eventsToWaitFor, Function.alwaysTrue, timeout)
    end

    function Events.waitForEventCondition(eventToWaitFor, condition, timeout)
      return Events.waitForOneOfEventsAndCondition({ eventToWaitFor }, condition, timeout)
    end

    function Events.waitForEvent(eventToWaitFor, timeout)
      return Events.waitForEventCondition(eventToWaitFor, Function.alwaysTrue, timeout)
    end

    function Events.waitForEvent2(eventToWaitFor, duration, timeout)
      local entry = {
        eventsToWaitFor = Set.create({ eventToWaitFor }),
        condition = Function.alwaysTrue,
        timeout = timeout,
        timer = nil,
        thread = coroutine.running(),
        duration = duration,
        timer2 = nil
      }

      _.addEntry(entry)

      return coroutine.yield()
    end

    Library.register(addOnName, version, Events)
  end
else
  error(addOnName .. ' requires Library. It seems absent.')
end

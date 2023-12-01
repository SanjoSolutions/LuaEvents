local addOnName = "Events"
local version = "2.1.0"

if _G.Library then
  if not Library.isRegistered(addOnName, version) then
    --- @type Boolean
    local Boolean = Library.retrieve("Boolean", "^2.0.0")
    --- @type Function
    local Function = Library.retrieve("Function", "^2.0.0")
    --- @type Set
    local Set = Library.retrieve("Set", "^1.1.0")
    --- @type Coroutine
    local Coroutine = Library.retrieve("Coroutine", "^2.0.0")
    --- @type Object
    local Object = Library.retrieve("Object", "^1.1.0")
    --- @type Array
    local Array = Library.retrieve("Array", "^2.0.0")

    --- @class Events
    local Events = {}

    local _ = {}

    local frame = nil
    local entries = {}
    local registeredEvents = {}
    -- frame -> event -> Set<Entry>
    local registeredNonOnEventEvents = {}
    -- frame -> event -> script
    local originalScripts = {}
    -- frame -> event -> boolean
    local isScriptRegistered = {}

    function _.removeRegisteredEvent(event, entry)
      if _.isOnEventEvent(event) then
        Set.remove(registeredEvents[event], entry)
        if Set.isEmpty(registeredEvents[event]) then
          frame:UnregisterEvent(event)
          Object.remove(registeredEvents, event)
          if Object.isEmpty(registeredEvents) then
            frame:SetScript("OnEvent", nil)
          end
        end
      elseif _.isNonOnEventEvent(event) then
        Set.remove(registeredNonOnEventEvents[event.frame][event.event], entry)
        if Set.isEmpty(registeredNonOnEventEvents[event.frame][event.event]) then
          local originalScript = originalScripts[event.frame][event.event]
          event.frame:SetScript(event.event, originalScript)
          Object.remove(registeredNonOnEventEvents[event.frame], event.event)
          originalScripts[event.frame][event.event] = nil
          isScriptRegistered[event.frame][event.event] = false
          if Object.isEmpty(registeredNonOnEventEvents[event.frame]) then
            Object.remove(registeredNonOnEventEvents, event.frame)
            originalScripts[event.frame] = nil
          end
        end
      end
    end

    local function finish(entry, wasSuccessful, event, ...)
      _.removeEntry(entry)

      Coroutine.resumeWithShowingError(entry.thread, wasSuccessful, event, ...)
    end

    function _.removeEntry(entry)
      _.cleanUpEntry(entry)
      Array.removeFirstOccurence(entries, entry)
    end

    function _.cleanUpEntry(entry)
      _.cancelTimerOfEntry(entry)
      _.removeRegisteredEventsOfEntry(entry)
    end

    function _.isScriptRegistered(event)
      return Boolean.toBoolean(isScriptRegistered[event.frame] and
        isScriptRegistered[event.frame][event.event])
    end

    function _.registerScript(event, callback)
      local script = event.frame:GetScript(event.event)

      if script then
        if not originalScripts[event.frame] then
          originalScripts[event.frame] = {}
        end
        originalScripts[event.frame][event.event] = script
      end

      event.frame:SetScript(event.event, function(...)
        if script then
          script(...)
        end
        callback(event, ...)
      end)

      if not isScriptRegistered[event.frame] then
        isScriptRegistered[event.frame] = {}
      end
      isScriptRegistered[event.frame][event.event] = true
    end

    function _.cancelTimerOfEntry(entry)
      if entry.timer and not entry.timer:IsCancelled() then
        entry.timer:Cancel()
      end
    end

    function _.removeRegisteredEventsOfEntry(entry)
      for event in Set.iterator(entry.eventsToWaitFor or entry.eventsToListenTo) do
        _.removeRegisteredEvent(event, entry)
      end
    end

    function Events.listenForEvent(event, callback)
      local entry = {
        eventsToListenTo = Set.create({ event, }),
        callback = callback,
        thread = coroutine.running(),
      }

      _.addEntry(entry)

      return {
        stopListening = function()
          _.removeEntry(entry)
        end,
      }
    end

    function Events.waitForOneOfEventsAndCondition(eventsToWaitFor, condition,
                                                   timeout)
      local entry = {
        eventsToWaitFor = Set.create(Array.map(eventsToWaitFor, function(event)
          if _.isNonOnEventEvent(event) then
            return Object.copy(event)
          else
            return event
          end
        end)),
        condition = condition,
        timeout = timeout,
        timer = nil,
        thread = coroutine.running(),
      }

      _.addEntry(entry)

      return coroutine.yield()
    end

    function _.addEntry(entry)
      if _.hasAnyOnEventEvents(entry) then
        table.insert(entries, entry)

        if not frame then
          frame = CreateFrame("Frame")
        end

        if not frame:GetScript("OnEvent") then
          frame:SetScript("OnEvent", function(self, event, ...)
            for _, entry in ipairs(entries) do
              if entry.eventsToWaitFor then
                if Set.contains(entry.eventsToWaitFor, event) and entry.condition(self, event, ...) then
                  if entry.duration then
                    if entry.timer2 then
                      entry.timer2:Cancel()
                      entry.timer2 = nil
                    end
                    local args = { ..., }
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

        local onEventEvents = Array.create(Set.toList(entry.eventsToWaitFor or
          entry.eventsToListenTo)):filter(_.isOnEventEvent)
        Array.forEach(onEventEvents, function(event)
          frame:RegisterEvent(event)
          if not registeredEvents[event] then
            registeredEvents[event] = Set.create()
          end
          Set.add(registeredEvents[event], entry)
        end)
      end

      if _.hasAnyNonOnEventEvents(entry) then
        if entry.eventsToWaitFor then
          local eventsToWaitFor = Array.filter(Set.toList(entry.eventsToWaitFor),
            function(event)
              return _.isNonOnEventEvent(event)
            end)
          Array.forEach(eventsToWaitFor, function(event)
            if not registeredNonOnEventEvents[event.frame] then
              registeredNonOnEventEvents[event.frame] = {}
            end
            if not registeredNonOnEventEvents[event.frame][event.event] then
              registeredNonOnEventEvents[event.frame][event.event] = Set.create()
            end
            Set.add(registeredNonOnEventEvents[event.frame][event.event], entry)

            if not _.isScriptRegistered(event) then
              _.registerScript(event, function(event, ...)
                local args = { ... }
                Array.forEach(
                  registeredNonOnEventEvents[event.frame][event.event]:toList(),
                  function(entry)
                    finish(entry, true, event, unpack(args))
                  end)
              end)
            end
          end)
        end

        if entry.eventsToListenTo then
          local eventsToListenTo = Array.filter(Set.toList(entry.eventsToListenTo),
            function(event)
              return _.isNonOnEventEvent(event)
            end)
          Array.forEach(eventsToListenTo, function(event)
            if not _.isScriptRegistered(event) then
              _.registerScript(event, function(event, ...)
                local args = { ... }
                Array.forEach(
                  registeredNonOnEventEvents[event.frame][event.event]:toList(),
                  function(entry)
                    entry.callback(event, unpack(args))
                  end)
              end)
            end
          end)
        end
      end

      if entry.timeout then
        entry.timer = C_Timer.NewTimer(entry.timeout, function()
          finish(entry, false)
        end)
      end
    end

    function _.hasAnyOnEventEvents(entry)
      return (entry.eventsToWaitFor and entry.eventsToWaitFor:containsWhichFulfillsCondition(_
            .isOnEventEvent)) or
          (entry.eventsToListenTo and entry.eventsToListenTo:containsWhichFulfillsCondition(_.isOnEventEvent))
    end

    function _.isOnEventEvent(eventToWaitFor)
      return type(eventToWaitFor) == "string"
    end

    function _.hasAnyNonOnEventEvents(entry)
      return (entry.eventsToWaitFor and entry.eventsToWaitFor:containsWhichFulfillsCondition(_
            .isNonOnEventEvent)) or
          (entry.eventsToListenTo and entry.eventsToListenTo:containsWhichFulfillsCondition(_
            .isNonOnEventEvent))
    end

    function _.isNonOnEventEvent(eventToWaitFor)
      return type(eventToWaitFor) == "table"
    end

    function Events.waitForOneOfEvents(eventsToWaitFor, timeout)
      return Events.waitForOneOfEventsAndCondition(eventsToWaitFor,
        Function.alwaysTrue, timeout)
    end

    function Events.waitForEventCondition(eventToWaitFor, condition, timeout)
      return Events.waitForOneOfEventsAndCondition({ eventToWaitFor, }, condition,
        timeout)
    end

    function Events.waitForEvent(eventToWaitFor, timeout)
      return Events.waitForEventCondition(eventToWaitFor, Function.alwaysTrue,
        timeout)
    end

    function Events.waitForEvent2(eventToWaitFor, duration, timeout)
      local entry = {
        eventsToWaitFor = Set.create({ eventToWaitFor, }),
        condition = Function.alwaysTrue,
        timeout = timeout,
        timer = nil,
        thread = coroutine.running(),
        duration = duration,
        timer2 = nil,
      }

      _.addEntry(entry)

      return coroutine.yield()
    end

    Library.register(addOnName, version, Events)
  end
else
  error(addOnName .. " requires Library. It seems absent.")
end

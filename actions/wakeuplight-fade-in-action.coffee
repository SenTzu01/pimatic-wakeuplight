module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  M = env.matcher
  
  class WakeuplightFadeInActionProvider extends env.actions.ActionProvider
    constructor: (@framework, @plugin) ->
      super()

    parseAction: (input, context) =>
      
      devices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.hasAction('changeDimlevelTo')
      ).value()
      
      device = null
      time = null
      match = null

      
      # Try to match the input string with:
      M(input, context)
        .match('fade in ')
        .matchDevice(devices, (next, d) =>
          next.match(' over ')
            .matchTimeDuration( (next, ts) =>
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              time = ts
              m = next.match([], optional: yes)
              match = m.getFullMatch()
            )
        )
      
      if match?
        assert device?
        assert time?
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new WakeuplightFadeInActionHandler(@framework, device, time)
        }
      else
        return null
  
  class WakeuplightFadeInActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @_device, @_time) ->
      super()
      @_faderTimeout = null

    setup: ->
      @dependOnDevice(@_device)
      super()

    executeAction: (simulate) =>
      @_play(simulate)

    _play: (simulate) =>
        if simulate
          return Promise.resolve("Would fade in #{@_device.name} over #{@_time.time} #{@_time.unit}")
        else
          @_fade(@_time.timeMs, 0)
          return Promise.resolve("Starting to fade in #{@_device.name} over #{@_time.time} #{@_time.unit}")
     
    _fade: (time, dimlevel) =>
      dimlevel += Math.floor(100 / (time / 1000))
      if dimlevel <= 100
        @_device.changeDimlevelTo(dimlevel)
        @_faderTimeout = setTimeout(@_fade, 1000, time, dimlevel )
      
      else
        @_device.changeDimlevelTo(100)
        clearTimeout(@_faderTimeout)
        env.logger.info("Fade in of #{device.name} done")
        @_faderTimeout = null
    
  return WakeuplightFadeInActionProvider

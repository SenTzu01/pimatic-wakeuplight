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
      @_maxLevel = 100
      @_minLevel = 0

    setup: ->
      @dependOnDevice(@_device)
      super()

    executeAction: (simulate) =>
      @_play(simulate)

    _play: (simulate) =>
        if simulate
          return Promise.resolve("Would fade in #{@_device.name} over #{@_time.time} #{@_time.unit}")
        else
          @_device.changeDimlevelTo(@_minLevel)
            
          @_fade(@_time.timeMs / 1000, @_minLevel)
          return Promise.resolve("Starting to fade in #{@_device.name} over #{@_time.time} #{@_time.unit}")
     
    _fade: (time, dimLevel) =>
      dimLevel += @_maxLevel / time
      current = Math.floor(dimLevel)
      if dimLevel < @_maxLevel
        @_device.getDimlevel().then( (old) =>
          @_device.changeDimlevelTo(current) if current > old
        ).then(() =>
          @_faderTimeout = setTimeout(@_fade, 1000, time, dimLevel )
        )
      
      else
        @_device.changeDimlevelTo(@_maxLevel)
        clearTimeout(@_faderTimeout)
        env.logger.info("Fade in of #{@_device.name} done")
        @_faderTimeout = null
    
  return WakeuplightFadeInActionProvider

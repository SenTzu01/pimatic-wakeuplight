module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  M = env.matcher
  
  class WakeuplightFadeOutActionProvider extends env.actions.ActionProvider
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
        .match('fade out ')
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
          actionHandler: new WakeuplightFadeOutActionHandler(@framework, device, time)
        }
      else
        return null
  
  class WakeuplightFadeOutActionHandler extends env.actions.ActionHandler
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
          return Promise.resolve("Would fade out #{@_device.name} over #{@_time.time} #{@_time.unit}")
        else
          @_fade(@_time.timeMs, 100)
          return Promise.resolve("Starting to fade out #{@_device.name} over #{@_time.time} #{@_time.unit}")
     
    _fade: (time, dimlevel) =>
      dimlevel -= Math.floor(100 / (time / 1000))
      if dimlevel >= 1
        @_device.changeDimlevelTo(dimlevel)
        @_faderTimeout = setTimeout(@_fadeIn, 1000, time, dimlevel )
      
      else
        @_device.changeDimlevelTo(0)
        clearTimeout(@_faderTimeout)
        @_faderTimeout = null
    
  return WakeuplightFadeOutActionProvider

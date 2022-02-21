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
      min = null
      match = null
      
      # Try to match the input string with:
      M(input, context).match('fade out ').matchDevice(devices, (next, d) =>
        if device? and device.id isnt d.id
          context?.addError(""""#{input.trim()}" is ambiguous.""")
          return
        device = d
      
        next.match(' to ').matchNumber( (next, ts) =>    
          min = ts
          next.match(' % over ', (next) =>
            next.matchTimeDuration( (next, ts) =>
              time = ts
              match = next.getFullMatch()
            )
          )
        )
      )
      
      if match?
        assert device?
        assert time?
        assert min?
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new WakeuplightFadeOutActionHandler(@framework, device, time, min)
        }
      else
        return null
  
  class WakeuplightFadeOutActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @_device, @_time, @_endLevel = 0) ->
      super()

    setup: ->
      @dependOnDevice(@_device)
      super()

    executeAction: (simulate) =>
      if simulate
        return Promise.resolve("Would fade out #{@_device.name} over #{@_time.time}#{@_time.unit}")
      
      else
        return Promise.delay(2000).then( () => # Delay 2 seconds to allow potential previous action on device to complete first
          @_device.getDimlevel()
        
        ).then( (currentlevel) =>
          @_fade(@_time.timeMs, currentlevel)
          Promise.resolve("Starting to fade out #{@_device.name} over #{@_time.time}#{@_time.unit}")
        )
     
    _fade: (time = 60 * 1000, startLevel) =>
      return new Promise( (resolve, reject) =>
        tick = () =>
          @_device.getDimlevel().then( (currentLevel) =>
            if currentLevel > @_endLevel
              
              @_device.changeDimlevelTo(currentLevel - 1).delay(time / (startLevel - @_endLevel)).then( () => 
                tick()
              
              ).catch( (error) => reject() )
            
            else
              env.logger.info("Fade in of #{@_device.name} completed")
              resolve()
          
          )
          .catch( (error) => reject(error) )
        
        tick()
      )
      
    destroy: () ->
      super()
    
  return WakeuplightFadeOutActionProvider

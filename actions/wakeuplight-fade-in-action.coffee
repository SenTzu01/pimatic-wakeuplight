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
      end = null
      match = null
      
      # Try to match the input string with:
      M(input, context).match('fade in ').matchDevice(devices, (next, d) =>
        if device? and device.id isnt d.id
          context?.addError(""""#{input.trim()}" is ambiguous.""")
          return
        device = d
      
        next.match(' to ').matchNumber( (next, ts) =>    
          end = ts
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
        assert end?
        assert time?
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new WakeuplightFadeInActionHandler(@framework, device, time, end)
        }
      else
        return null
  
  class WakeuplightFadeInActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @_device, @_time, @_endLevel = 100) ->
      @_tickTimeout = null
      super()

    setup: ->
      @dependOnDevice(@_device)
      super()

    executeAction: (simulate) =>
      if simulate
        return Promise.resolve("Would fade in #{@_device.name} over #{@_time.time}#{@_time.unit}")
      
      else
        setTimeout( @_fade, 2000, @_time.timeMs ) # Allow to complete potential previous rule action on device
        return Promise.resolve("Starting to fade in #{@_device.name} over #{@_time.time}#{@_time.unit}")
     
    _fade: (time = 60 * 1000) =>
      return new Promise( (resolve, reject) =>
        @_device.getDimlevel().then( (dimlevel) => 
          startLevel = dimlevel
          currentLevel = dimlevel
        
          tick = () =>
            timeStamp = Date.now()
            timeDiff = () => Date.now() - timeStamp
            
            ++currentLevel
            if currentLevel < @_endLevel
              @_device.changeDimlevelTo(currentLevel).then( () =>
                @_tickTimeout = setTimeout(tick, (time / (@_endLevel - startLevel)) - timeDiff())
              
              ).catch( (error) => reject() )
              
            else
              env.logger.info("Fade in of #{@_device.name} completed")
              clearTimeout(@_tickTimeout)
              @_tickTimeout = undefined
              resolve()
          
          tick()
        )
      )
    
    destroy: () ->
      clearTimeout(@_tickTimeout)
      @_tickTimeout = undefined
      super()
    
  return WakeuplightFadeInActionProvider

module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  
  
  deviceConfigTemplates = [
    #{
    #  "name": "Wakeuplight Device",
    #  "class": "Wakeuplight"
    #}
  ]
  
  actionProviders = [
    'wakeuplight-fade-in-action',
    'wakeuplight-fade-out-action'
  ]
  
  predicateProviders = [
    #'wakeuplight-predicate'
  ]
  
  class WakeuplightPlugin extends env.plugins.Plugin
    constructor: () ->
      
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @_base = commons.base @, 'Plugin'
      
      #deviceConfigDef = require("./device-config-schema")
      
      for device in deviceConfigTemplates
        className = device.class
        # convert camel-case classname to kebap-case filename
        filename = className.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase()
        classType = require('./devices/' + filename)(env)
        @_base.debug "Registering device class #{className}"
        @framework.deviceManager.registerDeviceClass(className, {
          configDef: deviceConfigDef[className],
          createCallback: @_callbackHandler(className, classType)
        })
      
      for provider in actionProviders
        className = provider.replace(/(^[a-z])|(\-[a-z])/g, ($1) ->
          $1.toUpperCase().replace('-','')) + 'Provider'
        classType = require('./actions/' + provider)(env)
        @_base.debug "Registering action provider #{className}"
        @framework.ruleManager.addActionProvider(new classType @framework, @)
      
      for provider in predicateProviders
        className = provider.replace(/(^[a-z])|(\-[a-z])/g, ($1) ->
          $1.toUpperCase().replace('-','')) + 'Provider'
        classType = require('./predicates/' + provider)(env)
        @_base.debug "Registering predicate provider #{className}"
        @framework.ruleManager.addPredicateProvider(new classType @framework, @)
      ###
      @framework.deviceManager.on('discover', () =>
        @_base.debug("Starting discovery")
        @framework.deviceManager.discoverMessage( 'pimatic-wakeuplight', "Searching for compatible devices" )
        
        _(@framework.deviceManager.devices).values().filter(
          (device) => device.hasAction('changeDimlevelTo')
        ).value().map( (device) =>
          @_createWakeuplightDevice(device)
        )
      )
      ###
    _callbackHandler: (className, classType) ->
      return (config, lastState) =>
        return new classType(config, @, lastState, @framework)
    
    _createWakeuplightDevice: (device) =>
      @base.debug("Creating new Wakeuplight device")
      @_createDevice({
        class: "Wakeuplight"
        name: "Wakeuplight " + device.name
        id: @_generateId(device.id)
      })
      
    _createDevice: (deviceConfig) =>
      @framework.deviceManager.discoveredDevice('pimatic-wakeuplight', "#{deviceConfig.name}", deviceConfig)
    
    _generateId: (name) =>
      "wakeuplight" + name.replace(/[^A-Za-z0-9\-]+/g, '-').toLowerCase()
        
    _destroy: () ->
  
  return new WakeuplightPlugin
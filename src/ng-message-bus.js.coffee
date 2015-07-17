'use strict'
angular.module('message-bus', []).factory 'MessageBus', [
  '$http', '$httpParamSerializerJQLike', '$timeout', '$document', '$q'
  ($http, $httpParamSerializerJQLike, $timeout, $document, $q)->

    document0 = $document[0]

    uniqueId = ->
      'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace /[xy]/g, (c)->
        r = Math.random() * 16 | 0
        v = if c is 'x' then r else (r & 0x3 | 0x8)
        v.toString(16)

    pollTimeout = lastAjax = hidden = undefined
    canceler = $q.defer()

    " webkit ms moz ms".split(' ').forEach (prefix)->
      check  = prefix + (if prefix is "" then "hidden" else "Hidden")
      hidden = check if(document0[check] isnt undefined )

    isHidden = ->
      return (
        if (hidden isnt undefined)
        then document0[hidden]
        else not document0.hasFocus
      )

    shouldLongPoll = -> me.alwaysLongPoll || !isHidden()

    processMessages = (messages)->
      gotData = false
      return false if (!messages) # server unexpectedly closed connection

      angular.forEach messages, (message) ->
        gotData = true
        angular.forEach me.callbacks, (callback)->
          if callback.channel is message.channel
            callback.last_id = message.message_id
            try
              callback.func(message.data)
            catch e
              console.log "MESSAGE BUS FAIL: callback #{callback.channel} caused exception #{e.message}"
          if (message.channel is "/__status")
            if (message.data[callback.channel] isnt undefined)
              callback.last_id = message.data[callback.channel]
      gotData

    longPoller = (poll, data) ->
      gotData = false
      aborted = false
      lastAjax = new Date()
      me.totalAjaxCalls += 1

      url = me.baseUrl + "message-bus/" + me.clientId + "/poll?" + ((if not shouldLongPoll() or not me.enableLongPolling then "dlp=t" else ""))
      $http.post(url, $httpParamSerializerJQLike(data), me.httpParams)
      .success((messages, status, headers, config)->
          me.failCount = 0
          if me.paused
            if messages
              me.later.push messages

          else
            gotData = processMessages(messages)

      ).error((messages, status, headers, config)->
        if status is 0
          aborted = true
        else
          me.failCount += 1
          me.totalAjaxFailures += 1
      ).finally ->
        interval = undefined
        if gotData or aborted
          interval = 100
        else
          interval = me.callbackInterval
          if me.failCount > 2
            interval = interval * me.failCount
          else interval = me.backgroundCallbackInterval  unless shouldLongPoll()
          interval = me.maxPollInterval  if interval > me.maxPollInterval
          interval -= (new Date() - lastAjax)
          interval = 100  if interval < 100

        pollTimeout = $timeout(->
          pollTimeout = null
          poll()
        , interval)
        me.longPoll = null

    me =
      alwaysLongPoll:    false
      baseUrl:           '/'
      callbackInterval:  15000
      callbacks:         []
      clientId:          uniqueId()
      enableLongPolling: true
      failCount:         0
      later:             []
      maxPollInterval:   3 * 60 * 1000
      paused:            false
      totalAjaxCalls:    0
      totalAjaxFailures: 0
      backgroundCallbackInterval: 60000
      httpParams:
        timeout: canceler.promise
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
          'X-SILENCE-LOGGER': 'true'
        }
        cache: false
      diagnostics: ->
        console.log("Stopped: " + me.stopped + " Started: " + me.started)
        console.log("Current callbacks")
        console.log(me.callbacks)
        console.log("Total ajax calls: #{me.totalAjaxCalls} Recent failure count: #{me.failCount} Total failures: #{me.totalAjaxFailures}")
        console.log("Last ajax call: " + (new Date() - lastAjax) / 1000  + " seconds ago")

      pause: -> me.paused = true; return

      resume: ->
        me.paused = false
        processMessages(me.later.pop()) while me.later.length
        return

      stop: -> me.stopped = true; me.started = false; return

      start: (opts = {}) ->
        angular.forEach opts, (value, key)->
          if typeof(me[key]) is 'object'
            angular.extend me[key], value
          else if typeof(me[key]) isnt 'undefined'
            me[key] = value

        delayPollTimeout = undefined
        return  if me.started
        me.started = true
        me.stopped = false
        poll = ->
          return  if me.stopped
          if me.callbacks.length is 0
            unless delayPollTimeout
              delayPollTimeout = $timeout(->
                delayPollTimeout = null
                poll()
              , 500)
            return
          data = {}
          me.callbacks.forEach (callback)->
            data[callback.channel] = callback.last_id

          me.longPoll = longPoller(poll, data)

        # monitor visibility, issue a new long poll when the page shows
        $document.bind('visibilitychange', visibilitychange = ->
          if not document0[hidden] and not me.longPoll and pollTimeout
            $timeout.cancel pollTimeout
            pollTimeout = null
            poll()
        )
        poll()
      subscribe: (channel, func, lastId)->
        me.start() if(!me.started && !me.stopped)

        lastId = -1 if (typeof(lastId) isnt "number" || lastId < -1)

        me.callbacks.push
          channel: channel
          func:    func
          last_id: lastId

        canceler.resolve() if (me.longPoll)

      unsubscribe: (channel, func)->
        if  channel.indexOf('*', channel.length - 1) != -1
          channel = channel.substr(0, channel.length - 1)
          glob    = true

        me.callbacks = me.callbacks.filter (callback)->
          if glob
            keep = callback.channel.substr(0, channel.length) != channel
          else
            keep = callback.channel != channel

          if(!keep && func && callback.func != func)
            keep = true
          keep

        canceler.resolve() if (me.longPoll)
]

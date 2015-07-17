describe 'MessageBus', ->
  MessageBus = $http = $timeout = $httpBackend = $document = url = null
  channel = '/some_channel'
  successRespond = [
    global_id:-1,
    message_id:-1
    channel:"/__status"
    data:{"/some_channel":11065}
  ]
  message =
    [
      global_id:13867
      message_id: 11066
      channel:"/some_channel"
      data:2
    ]

  beforeEach ->
    module 'message-bus'

    inject (_MessageBus_, _$http_, _$timeout_, _$document_, $injector) ->
      MessageBus = _MessageBus_
      $http      = _$http_
      $timeout   = _$timeout_
      $document  = _$document_
      $httpBackend = $injector.get('$httpBackend')
      url = "/message-bus/#{MessageBus.clientId}/poll?"

  it 'exists', ->
    expect(!!MessageBus).toBe yes

  it 'inits a clientId of length 32', ->
    expect(MessageBus.clientId.length).toBe 32

  'pause resume stop start subscribe unsubscribe'.split(' ').forEach (method)->
    it "has the '#{method}' method", ->
      expect(typeof MessageBus[method]).toBe 'function'

  describe 'starts with default options', ->
    beforeEach ->
      expect(MessageBus.stopped).not.toBe false
      expect(MessageBus.started).not.toBe true
      MessageBus.start()
      MessageBus.start()

    it 'enable longPolling', ->
      expect(MessageBus.enableLongPolling).toBe true

    it 'sets callbackInterval to 15000', ->
      expect(MessageBus.callbackInterval).toBe 15000

    it 'sets backgroundCallbackInterval to 60000', ->
      expect(MessageBus.backgroundCallbackInterval).toBe 60000

    it 'disable caching', ->
      expect(MessageBus.httpParams.cache).toBe false

  describe 'starts with specify options', ->
    enableLongPolling          = false
    callbackInterval           = 100
    backgroundCallbackInterval = 200
    alwaysLongPoll             = true
    baseUrl                    = 'http://example.com'
    httpParams                 = ignoreLoadingBar: true
    beforeEach ->
      expect(MessageBus.stopped).not.toBe false
      expect(MessageBus.started).not.toBe true
      MessageBus.start(
        enableLongPolling:          enableLongPolling
        callbackInterval:           callbackInterval
        backgroundCallbackInterval: backgroundCallbackInterval
        alwaysLongPoll:             alwaysLongPoll
        baseUrl:                    baseUrl
        httpParams:                 httpParams
      )

    it 'disable longPolling', ->
      expect(MessageBus.enableLongPolling).toBe enableLongPolling

    it 'sets callbackInterval to 100', ->
      expect(MessageBus.callbackInterval).toBe callbackInterval

    it 'sets backgroundCallbackInterval to 200', ->
      expect(MessageBus.backgroundCallbackInterval).toBe backgroundCallbackInterval

    it 'enable alwaysLongPoll', ->
      expect(MessageBus.alwaysLongPoll).toBe alwaysLongPoll

    it 'sets baseUrl', ->
      expect(MessageBus.baseUrl).toBe baseUrl

    it 'sets httpParams.ignoreLoadingBar to true', ->
      expect(MessageBus.httpParams.ignoreLoadingBar).toBe true

    it 'leaves caching param unchanged', ->
      expect(MessageBus.httpParams.cache).toBe false

    it 'started', ->
      expect(MessageBus.stopped).toBe false
      expect(MessageBus.started).toBe true

  describe 'subscribe', ->
    callback =
      fn: (message)-> console.log message
      error: ->
    beforeEach ->
      spyOn(callback, "fn")
      expect(MessageBus.stopped).not.toBe false
      expect(MessageBus.started).not.toBe true
      MessageBus.subscribe(channel, callback.fn)

    describe 'new channel when longPolling', ->
      beforeEach ->
        spyOn(callback, "error")
        $httpBackend.expectPOST(url).respond(message)
        $timeout.flush()
        expect($httpBackend.verifyNoOutstandingRequest).toThrow()
        expect(MessageBus.callbacks.length).toBe 1
        MessageBus.subscribe(channel, callback.error)

      it 'cancel current request', ->
        expect($httpBackend.verifyNoOutstandingExpectation).not.toThrow()

      it 'adds new channel into callbacks', ->
        expect(MessageBus.callbacks.length).toBe 2

    describe 'when success', ->
      beforeEach ->
        $httpBackend.whenPOST(url).respond(message)
        $timeout.flush()
        $httpBackend.flush()

      it 'starts', ->
        expect(MessageBus.stopped).toBe false
        expect(MessageBus.started).toBe true

      it 'records one ajax call', ->
        expect(MessageBus.totalAjaxCalls).toBe 1

      it 'does not fail', ->
        expect(MessageBus.totalAjaxFailures).toBe 0

      it 'fire the callback function', ->
        expect(callback.fn).toHaveBeenCalledWith(message[0].data)

      describe 'continue success', ->
        beforeEach -> $timeout.flush(); $httpBackend.flush()

        it 'records two ajax calls', ->
          expect(MessageBus.totalAjaxCalls).toBe 2

        it 'fire callback twice', ->
          expect(callback.fn.calls.count()).toEqual(2)

        it 'does not fail', ->
          expect(MessageBus.totalAjaxFailures).toBe 0

    describe 'when callback error', ->
      beforeEach ->
        $httpBackend.whenPOST(url).respond(message)
        spyOn(callback, "error").and.throwError("quux")
        MessageBus.subscribe(channel, callback.error)
        $timeout.flush()
        $httpBackend.flush()

      it 'log errors', ->
        expect(callback.fn.calls.count()).toEqual(1)
        expect(callback.error.calls.count()).toEqual(1)

    describe 'when empty message', ->
      beforeEach ->
        $httpBackend.whenPOST(url).respond(203, null)
        $timeout.flush()
        $httpBackend.flush()

      it 'records none failure', ->
        expect(MessageBus.totalAjaxFailures).toBe 0

    describe 'when channel message', ->
      beforeEach ->
        $httpBackend.whenPOST(url).respond(successRespond)
        $timeout.flush()
        $httpBackend.flush()

      it 'changes the channel id', ->
        expect(MessageBus.callbacks[0].last_id).toBe 11065

    describe 'when aborted', ->
      beforeEach ->
        $httpBackend.whenPOST(url).respond(0)
        $timeout.flush()
        $httpBackend.flush()

      it 'records none failure', ->
        expect(MessageBus.totalAjaxFailures).toBe 0

      it 'records one ajax call', ->
        expect(MessageBus.totalAjaxCalls).toBe 1

      it 'does not fire callback', ->
        expect(callback.fn.calls.count()).toEqual(0)

    describe 'when error', ->
      beforeEach ->
        $httpBackend.whenPOST(url).respond(401, '')
        $timeout.flush()
        $httpBackend.flush()

      it 'records one failure', ->
        expect(MessageBus.totalAjaxFailures).toBe 1

      it 'records one ajax call', ->
        expect(MessageBus.totalAjaxCalls).toBe 1

      it 'does not fire callback', ->
        expect(callback.fn.calls.count()).toEqual(0)


      describe 'continue success', ->
        beforeEach ->
          $httpBackend.expectPOST(url).respond(message)
          $timeout.flush(); $httpBackend.flush()

        it 'records two ajax call', ->
          expect(MessageBus.totalAjaxCalls).toBe 2

        it 'fire callback once', ->
          expect(callback.fn.calls.count()).toEqual(1)

        it 'still one failure', ->
          expect(MessageBus.totalAjaxFailures).toBe 1
  describe 'pause', ->
    callback = fn: (message)-> console.log message
    beforeEach ->
      spyOn(callback, "fn")
      MessageBus.subscribe(channel, callback.fn)
      expect(MessageBus.paused).toBe false
      expect(MessageBus.later.length).toBe 0
      MessageBus.pause()
      $httpBackend.whenPOST(url).respond(message)
      $timeout.flush()
      $httpBackend.flush()

    it 'paused', ->
      expect(MessageBus.paused).toBe true

    it 'does not fire callback', ->
      expect(callback.fn.calls.count()).toEqual(0)

    it 'records one message to process', ->
      expect(MessageBus.later.length).toBe 1

    it 'contains the message', ->
      expect(MessageBus.later).toContain message

    describe 'resume', ->
      beforeEach ->
        expect(MessageBus.paused).toBe true
        expect(MessageBus.later.length).toBe 1
        MessageBus.resume()

      it 'resume', ->
        expect(MessageBus.paused).toBe false

      it 'fire the callback function', ->
        expect(callback.fn).toHaveBeenCalledWith(message[0].data)

      it 'clears the message pool', ->
        expect(MessageBus.later.length).toBe 0

  describe 'unsubscribe', ->
    global_channel = '/global_channel*'
    callback =
      fn: (message)-> console.log message
      error: ->

    describe 'when specify channel', ->
      beforeEach ->
        $httpBackend.whenPOST(url).respond(message)
        spyOn(callback, "fn")
        spyOn(callback, "error").and.throwError("quux")
        MessageBus.subscribe(channel, callback.fn)
        MessageBus.subscribe(channel, callback.error)
        expect(MessageBus.callbacks.length).toBe 2
        $timeout.flush()

      it 'unsubscribe all callbacks', ->
        MessageBus.unsubscribe channel
        expect(MessageBus.callbacks.length).toBe 0

      it 'unsubscribe specify callback', ->
        MessageBus.unsubscribe channel, callback.fn
        expect(MessageBus.callbacks.length).toBe 1

    describe 'when global channel', ->
      beforeEach ->
        $httpBackend.whenPOST(url).respond(message)
        spyOn(callback, "fn")
        spyOn(callback, "error").and.throwError("quux")
        MessageBus.subscribe(global_channel, callback.fn)
        MessageBus.subscribe(global_channel, callback.error)
        expect(MessageBus.callbacks.length).toBe 2
        $timeout.flush()

      it 'unsubscribe all callbacks', ->
        MessageBus.unsubscribe global_channel
        expect(MessageBus.callbacks.length).toBe 0

      it 'unsubscribe specify callback', ->
        MessageBus.unsubscribe global_channel, callback.fn
        expect(MessageBus.callbacks.length).toBe 1

  describe 'stop', ->
    callback = fn: ->
    beforeEach ->
      spyOn(callback, "fn")
      MessageBus.subscribe(channel, callback.fn)
      expect(MessageBus.stopped).toBe false
      MessageBus.stop()
      $timeout.flush()

    it 'stopped', ->
      expect(MessageBus.stopped).toBe true

  describe 'diagnostics', ->
    it 'calls without errors', ->
      expect(MessageBus.diagnostics).not.toThrow()

  describe 'longPolling fail', ->
    callback = fn: ->
    beforeEach ->
      spyOn(callback, "fn")
      $document[0].hasFocus = false
      $httpBackend.whenPOST("#{url}dlp=t").respond(401, '')
      MessageBus.start
        enableLongPolling: false
        maxPollInterval: 99
      MessageBus.subscribe(channel, callback.fn)
      for i in [1...4]
        $timeout.flush()
        $httpBackend.flush()

    it 'sets interval to maxPollInterval', ->

  describe 'visibilitychange', ->
    it 'runs without error', ->
      triggerVisibilityChange = -> $document.triggerHandler 'visibilitychange'
      expect(triggerVisibilityChange).not.toThrow()

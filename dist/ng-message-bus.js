(function() {
  'use strict';
  angular.module('message-bus', []).factory('MessageBus', [
    '$http', '$httpParamSerializerJQLike', '$timeout', '$document', '$q', function($http, $httpParamSerializerJQLike, $timeout, $document, $q) {
      var canceler, document0, hidden, isHidden, lastAjax, longPoller, me, pollTimeout, processMessages, shouldLongPoll, uniqueId;
      document0 = $document[0];
      uniqueId = function() {
        return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
          var r, v;
          r = Math.random() * 16 | 0;
          v = c === 'x' ? r : r & 0x3 | 0x8;
          return v.toString(16);
        });
      };
      pollTimeout = lastAjax = hidden = void 0;
      canceler = $q.defer();
      " webkit ms moz ms".split(' ').forEach(function(prefix) {
        var check;
        check = prefix + (prefix === "" ? "hidden" : "Hidden");
        if (document0[check] !== void 0) {
          return hidden = check;
        }
      });
      isHidden = function() {
        return (hidden !== void 0 ? document0[hidden] : !document0.hasFocus);
      };
      shouldLongPoll = function() {
        return me.alwaysLongPoll || !isHidden();
      };
      processMessages = function(messages) {
        var gotData;
        gotData = false;
        if (!messages) {
          return false;
        }
        angular.forEach(messages, function(message) {
          gotData = true;
          return angular.forEach(me.callbacks, function(callback) {
            var e;
            if (callback.channel === message.channel) {
              callback.last_id = message.message_id;
              try {
                callback.func(message.data);
              } catch (_error) {
                e = _error;
                console.log("MESSAGE BUS FAIL: callback " + callback.channel + " caused exception " + e.message);
              }
            }
            if (message.channel === "/__status") {
              if (message.data[callback.channel] !== void 0) {
                return callback.last_id = message.data[callback.channel];
              }
            }
          });
        });
        return gotData;
      };
      longPoller = function(poll, data) {
        var aborted, gotData, url;
        gotData = false;
        aborted = false;
        lastAjax = new Date();
        me.totalAjaxCalls += 1;
        url = me.baseUrl + "message-bus/" + me.clientId + "/poll?" + (!shouldLongPoll() || !me.enableLongPolling ? "dlp=t" : "");
        return $http.post(url, $httpParamSerializerJQLike(data), me.httpParams).success(function(messages, status, headers, config) {
          me.failCount = 0;
          if (me.paused) {
            if (messages) {
              return me.later.push(messages);
            }
          } else {
            return gotData = processMessages(messages);
          }
        }).error(function(messages, status, headers, config) {
          if (status === 0) {
            return aborted = true;
          } else {
            me.failCount += 1;
            return me.totalAjaxFailures += 1;
          }
        })["finally"](function() {
          var interval;
          interval = void 0;
          if (gotData || aborted) {
            interval = 100;
          } else {
            interval = me.callbackInterval;
            if (me.failCount > 2) {
              interval = interval * me.failCount;
            } else {
              if (!shouldLongPoll()) {
                interval = me.backgroundCallbackInterval;
              }
            }
            if (interval > me.maxPollInterval) {
              interval = me.maxPollInterval;
            }
            interval -= new Date() - lastAjax;
            if (interval < 100) {
              interval = 100;
            }
          }
          pollTimeout = $timeout(function() {
            pollTimeout = null;
            return poll();
          }, interval);
          return me.longPoll = null;
        });
      };
      return me = {
        alwaysLongPoll: false,
        baseUrl: '/',
        callbackInterval: 15000,
        callbacks: [],
        clientId: uniqueId(),
        enableLongPolling: true,
        failCount: 0,
        later: [],
        maxPollInterval: 3 * 60 * 1000,
        paused: false,
        totalAjaxCalls: 0,
        totalAjaxFailures: 0,
        backgroundCallbackInterval: 60000,
        httpParams: {
          timeout: canceler.promise,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-SILENCE-LOGGER': 'true'
          },
          cache: false
        },
        diagnostics: function() {
          console.log("Stopped: " + me.stopped + " Started: " + me.started);
          console.log("Current callbacks");
          console.log(me.callbacks);
          console.log("Total ajax calls: " + me.totalAjaxCalls + " Recent failure count: " + me.failCount + " Total failures: " + me.totalAjaxFailures);
          return console.log("Last ajax call: " + (new Date() - lastAjax) / 1000 + " seconds ago");
        },
        pause: function() {
          me.paused = true;
        },
        resume: function() {
          me.paused = false;
          while (me.later.length) {
            processMessages(me.later.pop());
          }
        },
        stop: function() {
          me.stopped = true;
          me.started = false;
        },
        start: function(opts) {
          var delayPollTimeout, poll, visibilitychange;
          if (opts == null) {
            opts = {};
          }
          angular.forEach(opts, function(value, key) {
            if (typeof me[key] === 'object') {
              return angular.extend(me[key], value);
            } else if (typeof me[key] !== 'undefined') {
              return me[key] = value;
            }
          });
          delayPollTimeout = void 0;
          if (me.started) {
            return;
          }
          me.started = true;
          me.stopped = false;
          poll = function() {
            var data;
            if (me.stopped) {
              return;
            }
            if (me.callbacks.length === 0) {
              if (!delayPollTimeout) {
                delayPollTimeout = $timeout(function() {
                  delayPollTimeout = null;
                  return poll();
                }, 500);
              }
              return;
            }
            data = {};
            me.callbacks.forEach(function(callback) {
              return data[callback.channel] = callback.last_id;
            });
            return me.longPoll = longPoller(poll, data);
          };
          $document.bind('visibilitychange', visibilitychange = function() {
            if (!document0[hidden] && !me.longPoll && pollTimeout) {
              $timeout.cancel(pollTimeout);
              pollTimeout = null;
              return poll();
            }
          });
          return poll();
        },
        subscribe: function(channel, func, lastId) {
          if (!me.started && !me.stopped) {
            me.start();
          }
          if (typeof lastId !== "number" || lastId < -1) {
            lastId = -1;
          }
          me.callbacks.push({
            channel: channel,
            func: func,
            last_id: lastId
          });
          if (me.longPoll) {
            return canceler.resolve();
          }
        },
        unsubscribe: function(channel, func) {
          var glob;
          if (channel.indexOf('*', channel.length - 1) !== -1) {
            channel = channel.substr(0, channel.length - 1);
            glob = true;
          }
          me.callbacks = me.callbacks.filter(function(callback) {
            var keep;
            if (glob) {
              keep = callback.channel.substr(0, channel.length) !== channel;
            } else {
              keep = callback.channel !== channel;
            }
            if (!keep && func && callback.func !== func) {
              keep = true;
            }
            return keep;
          });
          if (me.longPoll) {
            return canceler.resolve();
          }
        }
      };
    }
  ]);

}).call(this);

//# sourceMappingURL=ng-message-bus.js.map

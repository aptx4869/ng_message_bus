# ng-message-bus
[![NPM version](https://badge.fury.io/js/ng-message-bus.svg)](http://badge.fury.io/js/ng-message-bus)
[![Bower version](https://badge.fury.io/bo/ng-message-bus.svg)](http://badge.fury.io/bo/ng-message-bus)
[![Built with Grunt](https://cdn.gruntjs.com/builtwith.png)](http://gruntjs.com/)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)
[![Build Status: Linux](https://travis-ci.org/aptx4869/ng_message_bus.svg?branch=master)](https://travis-ci.org/aptx4869/ng_message_bus)
[![Coverage Status](https://img.shields.io/coveralls/aptx4869/ng_message_bus.svg)](https://coveralls.io/r/aptx4869/ng_message_bus?branch=master)

## Example

```coffeescript

angular.module 'some_app', [
  'message-bus'
]
.controller('noticeController', [
  '$scope', 'MessageBus'
  ($scope, MessageBus)->
    MessageBus.start(httpParams: ignoreLoadingBar: true)

    subscribeFn = (n) -> $scope.notifications = n

    $scope.subscribe = ->
      MessageBus.subscribe "/notice", subscribeFn

    $scope.unsubscribe = ->
      MessageBus.unsubscribe "/notice", subscribeFn
])

```

## Installing
With [bower](http://bower.io/):
`bower install ng-message-bus`

With [npm](https://www.npmjs.org/):
`npm install ng-message-bus`

For Rails, installing with [rails-assets](https://rails-assets.org/) is recommended

In Gemfile:
```ruby
source 'https://rails-assets.org' do
  gem 'rails-assets-comment-core-library'
end
```

## License
Licensed under the MIT license

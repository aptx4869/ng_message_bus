module.exports = (grunt) ->
  require('load-grunt-tasks') grunt
  grunt.file.readJSON('package.json')

  License = "/*!Copyright(c) ng-message-bus (//github.com/aptx4869/ng_message_bus) - Licensed under the MIT License */\n"
  specHelpers = [
    'bower_components/angular/angular.js'
    'bower_components/angular-mocks/angular-mocks.js'
    'node_modules/jasmine-jquery/vendor/jquery/jquery.js'
    'node_modules/jasmine-jquery/lib/jasmine-jquery.js'
  ]

  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-jasmine')
  grunt.initConfig(
    clean:
      build: ['build/*', 'dist/*', 'compiled_spec/*', 'coverage/*']

    concat:
      all:
        files:
          'dist/ng-message-bus.js':  ['build/**/*.js']
    uglify:
      options: banner: License
      all:
        files:
          'dist/ng-message-bus.min.js': ['dist/ng-message-bus.js']

    # Watch files for changes
    #
    watch:
      dev:
        files: ['src/**/*', 'spec/**/*', '!node_modules']
        tasks: ['test']
      build:
        files: ['src/**/*', '!node_modules']
        tasks: ['build']

    # Jasmine test

    jasmine:
      coverage:
        src: 'build/**/*.js'
        options:
          specs: 'compiled_spec/*spec.js'
          helpers: 'spec/*helper.js'
          vendor: specHelpers
          template: require('grunt-template-jasmine-istanbul')
          templateOptions:
            report: 'coverage'
            coverage: 'coverage/coverage.json'
      ci:
        src: 'dist/ng-message-bus.js'
        options:
          specs: 'compiled_spec/*spec.js'
          helpers: 'spec/*helper.js'
          vendor: specHelpers
          template: require('grunt-template-jasmine-istanbul')
          templateOptions:
            report:
              type: 'lcovonly'
              options:
                dir:  'coverage'
            coverage: 'coverage/coverage.json'
    coffee:
      glob_to_multiple:
        options: sourceMap: true
        files: [
          {
            expand:  true,
            flatten: true,
            src:     ['spec/**/*.coffee']
            dest:    'compiled_spec/'
            ext:     '.js'
          },
          {
            expand:  true,
            flatten: true,
            cwd:     'src',
            src:     ['**/*.coffee']
            dest:    'build/'
            ext:     '.js'
          }
        ]
  )

  # Register special compiles

  # Register our tasks
  grunt.registerTask 'test', ['coffee', 'jasmine:coverage']
  grunt.registerTask 'build', ['coffee', 'concat', 'uglify:all']
  grunt.registerTask 'ci', ['build', 'jasmine:ci']
  grunt.registerTask 'default', ['clean', 'build', 'watch:dev']


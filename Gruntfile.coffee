module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'

    clean:
      default:
        src: ['lib']


    coffee:
      compile:
        options:
          bare: true
          join: false
        files: [
          expand: true
          cwd: 'src'
          src: '**/*.coffee'
          dest: 'lib'
          ext: '.js'
        ]

  grunt.loadTasks('tasks')
  grunt.loadNpmTasks('grunt-contrib-clean')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.registerTask('default', ['clean', 'coffee'])

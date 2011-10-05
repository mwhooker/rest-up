jade = require 'jade'
less = require 'less'
express = require 'express'
resource = require 'express-resource'
path = require 'path'
redis = require 'redis'

app = express.createServer(express.logger())

app.configure(() ->
    app.use express.compiler(src: path.dirname(__dirname) + '/static', enable: ['less'])
    app.use express.compiler(src: path.dirname(__dirname) + '/static', enable: ['coffeescript'])

    app.set('view engine', 'jade')
    app.set 'views', path.dirname(__dirname) + '/views'
    app.use(express.methodOverride())
    app.use(express.bodyParser())
    app.use(app.router)
    app.settings['view options'] = {
      _debug: false
    }
)

app.configure('development', () ->
    app.use express.static(path.dirname(__dirname) + '/static')
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }))

    app.set('redis', {
        port: 6379
        host: 'localhost'
    })

    app.settings['view options']['_debug'] = true
)

app.configure('production', () ->
    oneYear = 31557600000
    app.use express.static(path.dirname(__dirname) + '/static', { maxAge: oneYear })
    app.use(express.errorHandler())
)

redisClient = redis.createClient(
    app.set('redis').port, app.set('redis').host)

if app.set('redis').auth
    redisClient.auth(app.set('redis').auth)

app.get "/", (req, res) ->
    res.render('index')


crypto = require('crypto')

getUserIdCookieless = (req) ->
    shasum = crypto.createHash('sha1')

    id = req.connection.remoteAddress + ':'
    id += req.headers['user-agent']
    return shasum.update(id).digest('hex')


tastes = app.resource 'resource',

    index: (req, res) ->
        console.log getUserId(req)
        res.send(405)

    new: (req, res) ->
        res.render 'resource/new.jade'

    create: (req, res) ->
        res.send(req.body)

    show: (req, res) ->
        res.send(405)

    destroy: (req, res) ->
        res.send(405)

port = parseInt(process.env.PORT || 8000)
app.listen port

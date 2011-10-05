jade = require 'jade'
less = require 'less'
express = require 'express'
resource = require 'express-resource'
path = require 'path'
redis = require 'redis'
uuid = require 'node-uuid'


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

# temporary session hack
getUserIdCookieless = (req) ->
    shasum = crypto.createHash('sha1')

    id = req.connection.remoteAddress + ':'
    id += req.headers['user-agent']
    return shasum.update(id).digest('hex')

class Resource
    constructor: (@userId) ->

    create: (body) ->
        newId = uuid()
        @_saveDescription(body.path, body.description, newId)
        for method in ['get', 'put', 'post', 'delete', 'index']
            data = @_getMethodData(body, method)
            if data?
                @_saveMethod(data, method, newId)

    get: (id, method, cb) ->
        key = id + ':' + method
        redisClient.get key, (err, data) ->
            if err?
                console.log err
            cb JSON.parse data

    _saveMethod: (data, method, id) ->
        key = id + ':' + method
        console.log key
        redisClient.set key, JSON.stringify data

    _saveDescription: (path, description, id) ->
        # TODO: path can't contain /s
        key = @userId + ':' + id
        # add to userId set
        redisClient.sadd(@userId, key)
        # set description and path @ key
        redisClient.set key, JSON.stringify(
            path: path
            description: description
        )

    _getMethodData: (body, method) ->
        for key, value of body when key.split('_')[0] == method
            data = {} if not data?
            newKey = key.split('_')[1..].join '_'
            if newKey == 'body'
                try
                    data.body = JSON.parse(body[key])
                catch ex
                    data.body = body[key]
            else
                data[newKey] = body[key]
        return data


tastes = app.resource 'resource',

    index: (req, res) ->
        res.send(405)

    new: (req, res) ->
        res.render 'resource/new.jade'

    create: (req, res) ->
        resource = new Resource(getUserIdCookieless(req))
        resource.create req.body
        res.send(req.body)

    show: (req, res) ->
        res.send(405)

    destroy: (req, res) ->
        res.send(405)

app.get '/resource/:rid/:path', (req, res) ->
    resource = new Resource(getUserIdCookieless(req))
    data = resource.get(req.params.rid, 'index', (data) ->
        console.log data
        res.send(data.body, parseInt data.code)
    )

app.get '/resource/:rid/:path/:id', (req, res) ->
    resource = new Resource(getUserIdCookieless(req))
    data = resource.get(req.params.rid, 'get')
    res.send(data.body, data.code)

app.put '/resource/:rid/:path/:id', (req, res) ->
    resource = new Resource(getUserIdCookieless(req))
    data = resource.get(req.params.rid, 'put')
    res.send(data.body, data.code)

app.post '/resource/:rid/:path/:id', (req, res) ->
    resource = new Resource(getUserIdCookieless(req))
    data = resource.get(req.params.rid, 'post')
    res.send(data.body, data.code)

app.delete '/resource/:rid/:path/:id', (req, res) ->
    resource = new Resource(getUserIdCookieless(req))
    data = resource.get(req.params.rid, 'delete')
    res.send(data.body, data.code)

port = parseInt(process.env.PORT || 8000)
app.listen port

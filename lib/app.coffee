jade = require 'jade'
less = require 'less'
express = require 'express'
resource = require 'express-resource'
path = require 'path'
redis = require 'redis'
uuid = require 'node-uuid'
_ = require 'underscore'


app = express.createServer(express.logger())

app.configure(() ->
    app.use express.compiler(src: path.dirname(__dirname) + '/static', enable: ['less'])
    app.use express.compiler(src: path.dirname(__dirname) + '/static', enable: ['coffeescript'])

    app.set('view engine', 'jade')
    app.set 'views', path.dirname(__dirname) + '/views'
    app.use(express.methodOverride())
    app.use(express.bodyParser())
    app.use(express.cookieParser())

    # TODO: use req.session w/ hmac. we don't really want a session
    # (in memory store, 1 day exp)
    secret = process.env.COOKIE_SECRET || 'foobar'
    app.use(express.session(secret: secret))

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

getUserId = (req) ->
    return 'testKey'
    if not req.session.id?
        req.session.id = uuid()
    return req.session.id

parseJson = (input) ->
    try
        JSON.parse input
    catch ex
        input

class Resource

    @methods: ['get', 'put', 'post', 'delete', 'index']

    constructor: (@userId) ->

    create: (body) ->
        newId = uuid()
        @_saveDescription(body.path, body.description, newId)
        for method in Resource.methods
            data = @_getMethodData(body, method)
            if data?
                @_saveMethod(data, method, newId)
        newId


    delete: (rid, cb) ->

        deleteMethods = (rid, cb) ->
            keys = (rid + ':' + method for method in Resource.methods)
            redisClient.del keys, (err, ret) ->
                if err?
                    cb err
                    return
                cb null, ret


        redisClient.srem @userId, rid, (err, ret) ->
            if err?
                cb err
                return
            if ret == 0
                cb null, false
                return

            deleteMethods rid, (err, deleted) ->
                if err?
                    cb err
                else
                    cb null, true


    getAll: (cb) ->
        redisClient.smembers @userId, (err, members) ->
            if err?
                console.log err
            redisClient.mget members, (err, descs) ->
                if err?
                    console.log err
                ids = (member.split(':')[1] for member in members)
                # TODO: clean this shit up.
                cb ((_.extend JSON.parse(desc), id: id) for [id, desc] in (_.zip ids, descs))

    @getAllMethods: (id, cb) ->
        keys = (id + ':' + method for method in Resource.methods)
        redisClient.mget keys, (err, results) ->
            resObj = {}
            for lr in _.zip Resource.methods, results
                if lr[1]?
                    resObj[lr[0]] = JSON.parse lr[1]
            cb(resObj)

    @get: (id, method, cb) ->
        key = id + ':' + method
        redisClient.get key, (err, data) ->
            if err?
                console.log err
            cb JSON.parse data

    getDescription: (id, cb) ->
        key = @userId + ':' + id
        redisClient.get key, (err, data) ->
            cb JSON.parse data

    _saveMethod: (data, method, id) ->
        key = id + ':' + method
        redisClient.set key, JSON.stringify data

    _saveDescription: (path, description, id) ->
        # TODO: path can't contain slashes
        # TODO: path/title inconsistencies
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
                data.body = JSON.parse body[key]
            else if newKey == 'code'
                data.code = parseInt body[key]
            else
                data[newKey] = body[key]

        if data? and data.header_name? and data.header_value?
            # TODO: validate every header value has a key in the frontend.
            headers = {}
            if _.isArray data.header_name and _.isArray data.header_value
                for lr in _.zip data.header_name, data.header_value
                    headers[lr[0]] = lr[1]
            else
                headers[data.header_name] = data.header_value
            delete data.header_name
            delete data.header_value
            data.headers = headers

        return data


# TODO: stick user ID in URL (?)
resources = app.resource 'resource',

    index: (req, res) ->
        resource = new Resource(getUserId(req))
        resource.getAll (resources) ->
            if req.accepts 'application/json'
                res.send resources
            else if req.accepts 'html'
                console.log resources
                res.render 'resource/index.jade', resources: resources
            else
                res.send 415

    new: (req, res) ->
        res.render 'resource/new.jade'

    create: (req, res) ->
        resource = new Resource(getUserId(req))
        id = resource.create req.body
        res.send 303, Location: '/resource/' + id

    show: (req, res) ->
        acc = 0
        data = {}
        done = (results) ->
            if _.isArray results
                for r in results
                    data = _.extend data, r
            else
                data = _.extend(data, results)
            acc += 1
            if acc == 2
                if req.accepts 'application/json'
                    res.send data
                else if req.accepts 'html'
                    res.render 'resource/show.jade', resource: data
                else
                    res.send 415

        resource = new Resource getUserId req
        resource.getDescription req.params.resource, (results) ->
            done(results)

        Resource.getAllMethods req.params.resource, (results) ->
            done(results)

    destroy: (req, res) ->
        resource = new Resource getUserId req
        resource.delete req.params.resource, (err, suc) ->
            if err?
                res.send 500
            else if not suc
                res.send 404
            else
                res.send 200


#TODO: remove X-Powered-By
handle = (method) ->
    (req, res) ->
        data = Resource.get req.params.rid, method, (data) ->
            if not data?
                res.send 404
            else
                res.json(data.body, data.headers, data.code)


app.get '/resource/:rid/:path', handle 'index'
app.post '/resource/:rid/:path', handle 'post'

app.get '/resource/:rid/:path/:id', handle 'get'
app.put '/resource/:rid/:path/:id', handle 'put'
app.delete '/resource/:rid/:path/:id', handle 'delete'

port = parseInt(process.env.PORT || 8000)
app.listen port

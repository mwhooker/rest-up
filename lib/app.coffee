jade = require 'jade'
less = require 'less'
express = require 'express'

app = express.createServer(express.logger())

app.configure(() ->
    app.use express.compiler(src: '/../static', enable: ['less'])

    app.set('view engine', 'jade')
    app.set('views', __dirname + '/../views')
    app.use(express.methodOverride())
    app.use(express.bodyParser())
    app.use(app.router)
    app.settings['view options'] = {
      _debug: false
    }
)

app.configure('development', () ->
    app.use(express.static(__dirname + '/../static'))
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }))

    app.settings['view options']['p_debug'] = true
)

app.configure('production', () ->
    oneYear = 31557600000
    app.use(express.static(__dirname + '/../static', { maxAge: oneYear }))
    app.use(express.errorHandler())
)

app.get "/", (req, res) ->
    res.render('index')


port = parseInt(process.env.PORT || 8000)
app.listen port

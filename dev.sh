#!/bin/sh

NODE_MODULES="`dirname $0`/node_modules"

NODE_ENV=development $NODE_MODULES/coffee-script/bin/coffee ./lib/app.coffee

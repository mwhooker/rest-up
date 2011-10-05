window.addHeader = (method) ->
    $('#' + method).append _.template $('#header_tpl').text(), method: method

window.addResponse = (method) ->
    methodForm = _.template $('#response_tpl').text(), method: method
    $('#' + method).replaceWith methodForm

$(document).ready () ->
    _.templateSettings = interpolate: /XX([^X{2}]+?)XX/g

    #_.each ['get', 'put', 'post', 'delete'], (method) ->
    #    $('#input').append _.template $('#response_tpl').text(), method: method

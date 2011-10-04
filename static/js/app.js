(function() {

    $(document).ready(function() {
        _.templateSettings = {
            interpolate : /XX([^X{2}]+?)XX/g
        };
        _.each(['get', 'put', 'post', 'delete'], function(method) {
            $('#input').append(
                _.template($('#response_tpl').text(), {method: method})
            );
        });
    });
})();

# rest up

## Storage Model

Each user will have a cookie-baked session which will hold a UUID
The UUID will map to a list of endpoint keys

An endpoint key contains a new UUID and the method, and looks like this:

	UUID():METHOD

For example:

	24678611-169e-49f3-921f-59fddb9486d2:GET

The Endpoint description key will consist of the user's UUID and the endpoint key UUID:

	<User id>:<endpoint id>
	1234:24678611-169e-49f3-921f-59fddb9486d2

Tying the user_id to the description key will make sure that only the user can modify the endpoint.

The endpoint description key will map to a data block which looks like this:
	{
		'path': 'resource/:id',
		'description': 'The thing.',
	}


An endpoint key will address a data block which may look like this:

	{
		'code': 201,
		'headers': {
			'location': '/blah/1'
		},
		'body': {
			'foo': 'bar'
		}
	}


## Implementation

A client will make requests against their endpoints like so:

	GET /<UUID>/<path>

The application will look up the endpoint by constructing an endpoint key:

	<UUID>:GET

and will return the result.
This method allows the user to share their endpoints with anyone that has the URL.




## Data object of a REST endpoint as received from POST /resource:

	{
		'path': 'resource/:id',
		'description': 'The thing.',
		'get': {
			'body': {
				'name': 'example',
				'dob': '1986-10-24'
			},
			'code': 200
		},
		'put': {
			'code': 200
		},
		'delete': {
			'code': 200
		},
		'post': {
			'code': 201,
			'headers': {
				'location': '/blah/1'
			},
			'body': {
				'foo': 'bar'
			}
		}
	}

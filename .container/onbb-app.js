/*
 * This file is a wrapper around original app.js from NodeBB.
 * It sets up config overrides using values from container environment,
 * and then requires original app.js (now renamed to _app.js) to let
 * NodeBB continue it's magic.
 */
var nconf = require('nconf');
var url   = require('url');

var testSSL = require('/app/.container/tools/test-ssl.js');

var IP   = process.env.CONTAINER_NODEJS_IP   || null;
var PORT = process.env.CONTAINER_NODEJS_PORT || null;
var WSPORT = process.env.CONTAINER_WEBSOCKET_PORT || null;

// Fully Qualified Domain Name
var FQDN = process.env.CONTAINER_APP_DNS_ALIAS || process.env.CONTAINER_APP_DNS || null;

// Check is SSL is working on selected domain name
testSSL(IP, PORT, FQDN, function onTestSSLResult (err) {
	'use strict';

	// HTTPS or HTTP and WSS or WS
	var USE_SSL = err ? false : true;

	// Prepare config overrides
	var config = {};

	// Port number
	if (PORT) {
		config.port = PORT;
	}

	// Bind to IP address
	if (IP) {
		config.bind_address = IP;
	}

	// Default domain name
	if (FQDN) {
		config.url = (USE_SSL ? 'https' : 'http') + '://' + FQDN;

		// OpenShift supports websockets but only on ports 8000 and 8443
		config['socket.io'] = config['socket.io'] || {};

		if (USE_SSL) {
			config['socket.io'].address = 'wss://' + FQDN + ':' + (WSPORT || '8433');
		}
		else {
			config['socket.io'].address = 'ws://' + FQDN + ':' + (WSPORT || '8000');
		}

		// TODO: support multiple domain names? If so, "socket.io".origigns changed from string to array of strings in v1.16.0
	}

	// MongoDB is preferred by default
	if (process.env.CONTAINER_MONGODB_DB_HOST || process.env.CONTAINER_MONGODB_IP || process.env.CONTAINER_MONGODB_DB_PASSWORD) {
		config.database = config.database || 'mongo';
		config.mongo = config.mongo || {};

		// OpenShift seems to create MongoDB database with the same name as the application name.
		config.mongo.database = process.env.CONTAINER_MONGODB_DB_NAME || process.env.CONTAINER_APP_NAME || 'nodebb';

		if (process.env.CONTAINER_MONGODB_DB_HOST || process.env.CONTAINER_MONGODB_IP) {
			config.mongo.host = process.env.CONTAINER_MONGODB_DB_HOST || process.env.CONTAINER_MONGODB_IP;
		}
		if (process.env.CONTAINER_MONGODB_DB_PORT) {
			config.mongo.port = process.env.CONTAINER_MONGODB_DB_PORT;
		}
		if (process.env.CONTAINER_MONGODB_DB_USERNAME) {
			config.mongo.username = process.env.CONTAINER_MONGODB_DB_USERNAME;
		}
		if (process.env.CONTAINER_MONGODB_DB_PASSWORD) {
			config.mongo.password = process.env.CONTAINER_MONGODB_DB_PASSWORD;
		}
	}

	// MongoLab is preferred by default
	if (process.env.MONGOLAB_URI) {
		config.database = config.database || 'mongo';
		config.mongo = config.mongo || {};
		
		var mongolabURL = url.parse(process.env.MONGOLAB_URI);
		mongolabURL.auth = mongolabURL.auth.split(':');
		
		config.mongo.host = mongolabURL.hostname;
		config.mongo.port = mongolabURL.port;
		config.mongo.username = mongolabURL.auth[0];
		config.mongo.password = mongolabURL.auth[1];
		config.mongo.database = mongolabURL.pathname.substring(1);
	}

	// PostgreSQL is preferred before Redis as a main DB
	if (process.env.CONTAINER_POSTGRES_HOST || process.env.CONTAINER_POSTGRES_PASSWORD) {
		config.database = config.database || 'postgres';
		config.postgres = config.postgres || {};

		config.postgres.database = process.env.CONTAINER_POSTGRES_DB || process.env.CONTAINER_APP_NAME || 'nodebb';
		config.postgres.ssl = process.env.CONTAINER_POSTGRES_SSL || false;

		if (process.env.CONTAINER_POSTGRES_HOST) {
			config.postgres.host = process.env.CONTAINER_POSTGRES_HOST;
		}
		if (process.env.CONTAINER_POSTGRES_PORT) {
			config.postgres.port = process.env.CONTAINER_POSTGRES_PORT;
		}
		if (process.env.CONTAINER_POSTGRES_USER) {
			config.postgres.username = process.env.CONTAINER_POSTGRES_USER;
		}
		if (process.env.CONTAINER_POSTGRES_PASSWORD) {
			config.postgres.password = process.env.CONTAINER_POSTGRES_PASSWORD;
		}
	}

	// Redis - by setting it up last, we make sure it will not override MongoDB or PostgreSQL as default database.
	// That allows us to have two databases, with Redis used only as socket.io-session store.
	if (process.env.CONTAINER_REDIS_HOST || process.env.REDIS_PASSWORD) {
		config.database = config.database || 'redis';
		config.redis = config.redis || {};

		if (process.env.CONTAINER_REDIS_HOST) {
			config.redis.host = process.env.CONTAINER_REDIS_HOST;
		}
		if (process.env.CONTAINER_REDIS_PORT) {
			config.redis.port = process.env.CONTAINER_REDIS_PORT;
		}
		if (process.env.REDIS_PASSWORD) {
			config.redis.password = process.env.REDIS_PASSWORD;
		}
	}

	// Set overrides from container environment
	nconf.overrides(config);

	// Cleanup
	config = null;
	testSSL = null;
	IP = PORT = FQDN = null;

	// TODO: Does not work, as process is different for webserver than main app
	// require('/app/.container/lib/onbb_utils.js').onbb_start_command_server();

	// Continue booting NodeBB
	setImmediate(require.bind(null, './_app.js'));
});

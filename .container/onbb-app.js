/*
 * This file is a wrapper around original js file from NodeBB, e.g., app.js.
 * It sets up config overrides using values from container environment,
 * and then requires original file (now prefixed with underscore, e.g., _app.js)
 * to let NodeBB continue it's magic.
 */
var nconf = require('nconf');
var url   = require('url');
var path  = require('path');

// Require colors, because when update is called not through cli/index, it will crash
require('colors');

var testSSL = require('/app/.container/tools/test-ssl.js');

// Port that NodeBB will be listening on
var PORT = process.env.PORT || process.env.port || 4567;

// Patially Qualified Domain Name
// Fully Qualified Domain Name should end with a dot, so strip it.
var PQDN = (process.env.APP_USE_FQDN || 'localhost').replace(/\.$/, '')

// URL to test
var URL = PQDN + (process.env.APP_USE_PORT ? ':' + process.env.APP_USE_PORT : '');

// Check is SSL is working on selected domain name
testSSL(PORT, URL, function onTestSSLResult (err) {
	'use strict';

	// HTTPS or HTTP and WSS or WS
	var USE_SSL = err ? false : true;

	// Prepare config overrides
	var config = {};

	// Port number
	if (PORT) {
		config.port = PORT;
	}

	// Default domain name
	if (URL) {
		config.url = (USE_SSL ? 'https' : 'http') + '://' + URL;

		config['socket.io'] = config['socket.io'] || {};
		config['socket.io'].address = (USE_SSL ? 'wss://' : 'ws://') + URL;

		// if (USE_SSL) {
		// 	config['socket.io'].address = 'wss://' + URL + ':' + PORT;
		// }
		// else {
		// 	config['socket.io'].address = 'ws://' + URL + ':' + PORT;
		// }

		// TODO: support multiple domain names? If so, "socket.io".origins changed from string to array of strings in v1.16.0
	}

	// MongoDB is preferred by default
	if (process.env.CONTAINER_MONGODB_HOST || process.env.CONTAINER_MONGODB_IP || process.env.CONTAINER_MONGODB_PASSWORD) {
		config.database = config.database || 'mongo';
		config.mongo = config.mongo || {};

		// OpenShift seems to create MongoDB database with the same name as the application name.
		config.mongo.database = process.env.CONTAINER_MONGODB_NAME || process.env.APP_NAME || 'nodebb';

		if (process.env.CONTAINER_MONGODB_HOST || process.env.CONTAINER_MONGODB_IP) {
			config.mongo.host = process.env.CONTAINER_MONGODB_HOST || process.env.CONTAINER_MONGODB_IP;
		}
		if (process.env.CONTAINER_MONGODB_PORT) {
			config.mongo.port = process.env.CONTAINER_MONGODB_PORT;
		}
		if (process.env.CONTAINER_MONGODB_USERNAME) {
			config.mongo.username = process.env.CONTAINER_MONGODB_USERNAME;
		}
		if (process.env.CONTAINER_MONGODB_PASSWORD) {
			config.mongo.password = process.env.CONTAINER_MONGODB_PASSWORD;
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

		config.postgres.database = process.env.CONTAINER_POSTGRES_DB || process.env.APP_NAME || 'nodebb';
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

		config.redis.database = process.env.CONTAINER_REDIS_DB || 0;

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
	PORT = PQDN = URL = null;

	// Continue to whatever file was meant to be started.
	setImmediate(require.bind(null, './_' + path.basename(module.filename)));
});

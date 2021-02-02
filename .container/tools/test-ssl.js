#!/usr/bin/env node

/**
 * This script will temporarily start webserver on HTTP and send request to it
 * through a specified domain using HTTPS to check if it works ok, e.g.,
 * if certificate is valid, if connection is routed correctly, etc...
 */
var https = require('https');
var http  = require('http');
var path  = require('path');

/**
 * Start server for a time of single request, check if it responds with correct data.
 * Depend on Node to check SSL certificate validity.
 *
 * @param {!number}   port       Port number to listen on
 * @param {!string}   url        URL to try
 * @param {!Function} callback   Will call with error or null as first argument
 */
function testSSL (port, url, callback) {
	// If something terminates SSL and passes requests through a regular HTTP,
	// NodeBB should be listening for HTTP, not HTTPS.
	// So we setup a HTTP server, and call it through HTTPS, to see if that's the case.
	var header = 'X-Containerized-NodeBB-Test';
	var token = "" + Math.random();

	var server = http.createServer(function (req, res) {
		res.setHeader(header, token);
		res.writeHead(200, {'Content-Type': 'text/plain', 'Connection': 'close'});
		res.end('OK');
	});

	var cleanup = function cleanup (err) {
		if (!server) {
			return;
		}

		server.close(callback.bind(null, err));
		server = null;
		cleanup = null;
	};

	server.on('error', cleanup);

	server.listen(port, null, null, function onListening () {
		https.get('https://' + url.replace(/^\s*https?:\/\//, ''), function (res) {
			res.on('data', function () {});
			cleanup(res.headers[header.toLowerCase()] !== token ? new Error('Wrong data returned') : null);
		}).on('error', cleanup);
	});
};

/*
 * Exports
 */
if (typeof module === 'object') {
	module.exports = testSSL;
}

// Exit if we're not called as a standalone application
if (require.main !== module) {
	return;
}

// Get args passed from command line
var argv = process.argv.slice();

/**
 * Domain name to be tested.
 *
 * @type {string}
 */
var testURL = argv.pop();

/**
 * Port number to be used for test
 *
 * @type {number}
 */
var testPORT = Math.min(Math.max(parseInt(argv.pop() || '', 10), 0), 65535);

// If one of args is not valid, show usage info and exit.
if (isNaN(testPORT) || !testURL) {
	var filename = path.basename(module.filename);
	console.log('USAGE: ' + filename + ' port url');
	console.log('EXAMPLE: ' + filename + ' 4567 ' + (process.env.APP_USE_FQDN || 'example.com') + (process.env.APP_USE_PORT ? ':' + process.env.APP_USE_PORT : ''));
	return process.exit(1);
}

// Run test
testSSL(testPORT, testURL, function (err) {
	if (err) {
		console.error(err);
	}

	process.exit(err ? 1 : 0);
});
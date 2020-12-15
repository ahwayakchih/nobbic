#!/usr/bin/env node

/**
 * This script will read output of tails from logs until either:
 *
 * - line about NodeBB listening is found
 * - time runs out
 */
var spawn = require('child_process').spawn;
var path  = require('path');

var NODEBB_IS_RUNNING_REGEX = /NodeBB is now listening on:/;

/**
 * Spawn `tail -f -n 0 logs/output.log` process and wait until output about NodeBB listening shows up
 * or time runs out.
 *
 * @param {number}   [timeout=120000] Miliseconds before assuming failure
 * @param {Function} [callback]       Will be called with error or null as first argument
 */
function waitForNodeBBToStart (timeout, callback) {
	var tail;
	var result = false;
	var startTime;

	if (!callback && timeout instanceof Function) {
		callback = timeout;
		timeout = null;
	}

	if (!timeout) {
		// 2 minutes
		timeout = 120000;
	}

	tail = spawn('tail', ['-F', '-n', '0', path.join(process.env.CONTAINER_REPO_DIR, 'nodebb/logs/output.log')]);
	var logs = '';
	var errors = '';

	tail.stdout.on('data', function (data) {
		if (!tail) {
			return;
		}

		logs = (logs + data.toString('utf8')).replace(/[^\n]*\n/g, function (chunk) {
			console.log(chunk);

			if (NODEBB_IS_RUNNING_REGEX.test(chunk)) {
				result = true;
			}

			return '';
		});

		if (result) {
			tail.kill();
			tail = null;
		}
	});

	tail.stderr.on('data', function (data) {
		if (!tail) {
			return;
		}

		errors = (errors + data.toString('utf8')).replace(/[^\n]*\n/g, function (chunk) {
			console.error(chunk);
			return '';
		});
	});

	tail.on('close', function (code, signal) {
		var err = null;

		if (!result) {
			if (errors.length) {
				console.error(errors);
			}

			if (Date.now() - startTime >= timeout) {
				err = new Error('Error: Timeout');
			}
			else if (!code && signal) {
				err = new Error('Error: Killed with ' + signal);
			}
			else {
				err = new Error('Error: Exited with code: ' + code + ' and signal: ' + signal);
			}
		} 

		callback(err);
	});

	startTime = Date.now();
	setTimeout(tail.kill.bind(tail), timeout);
};

/*
 * Exports
 */
if (typeof module === 'object') {
	module.exports = waitForNodeBBToStart;
}

// Exit if we're not called as a standalone application
if (require.main !== module) {
	return;
}

// Get args passed from command line
var argv = process.argv.slice();

/**
 * Timeout in miliseconds
 *
 * @type {number}
 */
var timeout = parseInt(argv.pop(), 10) || null;

// Start waiting
waitForNodeBBToStart(timeout, function (err) {
	if (err) {
		console.error(err.message);
	}

	process.exit(err ? 1 : 0);
});
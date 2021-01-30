const net   = require('net');
const fs    = require('fs');

// These are installed by NodeBB, so we do not need to install them
const nconf = require.main.require('nconf');
const async = require.main.require('async');

// Our stuff
const CommandServer = require('./CommandServer');

/**
 * Our custom commands.
 *
 * @type {CommandsMap}
 */
const COMMANDS = {};

/**
 * Dump current config object.
 *
 * @type {CommandHandler}
 */
COMMANDS.config = function config (done) {
	done(null, JSON.stringify(nconf.get()));
};

/**
 * Generate reset code for user with given e-mail address.
 *
 * @type {CommandHandler}
 * @param {string} email
 */
COMMANDS.resetPassword = function resetPassword (done, email) {
	if (!email) {
		return setImmediate(done.bind(null, 'E-mail parameter is missing'));
	}

	// NodeBB stuff
	const User      = require.main.require('./src/user');
	const UserReset = require.main.require('./src/user/reset');

	async.waterfall([
		function(next) {
			User.getUidByEmail(email, next);
		},
		function(uid, next) {
			if (!uid) {
				return next(new Error('Mail not found'));
			}
			UserReset.generate(uid, next);
		},
		function(code, next) {
			next(null, nconf.get('url') + '/reset/' + code);
		}
	], done);
};

/**
 * Create CommandsServer and start it after webserver starts listening.
 * Listen on `onbb-[NodeBB port number].sock` by default.
 *
 * Server will close automatically when process is killed.
 *
 * **WARNING:** this will work ONLY along with NodeBB application,
 *              so it must be called from the same process that
 *              started NodeBB's webserver.
 *
 * @return {CommandServer}
 */
function onNodeBBReady () {
	const server = new CommandServer({commands: COMMANDS});

	// NodeBB stuff
	const webserver = require.main.require('./src/webserver');

	// Wait for NodeBB webserver to start listening
	webserver.server.on('listening', () => {
		if (server.listening) {
			return;
		}

		var nodebbAddress = webserver.server.address();
		address = 'nbb-cmd-' + (nodebbAddress.port || nodebbAddress) + '.sock';

		server.start(address);
	});

	process.on('SIGTERM', server.stop.bind(server));
	process.on('SIGINT', server.stop.bind(server));

	return server;
}

/*
 * Exports
 */
module.exports.onNodeBBReady = onNodeBBReady;

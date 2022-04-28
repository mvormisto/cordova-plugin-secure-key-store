// JS interface
var exec = require('cordova/exec');

var SecureKeyStore = {
	serviceName: "SecureKeyStore",

	get: function (service, key) {
		return new Promise((resolve) => exec(resolve, (error => resolve()), this.serviceName, "get", [service, key]));
	},

	set: function(service, key, value) {
		return new Promise((resolve, reject) => exec(() => resolve(), reject, this.serviceName, "set", [service, key, value]));
	},

	remove: function (service, key) {
		return new Promise((resolve) => exec(() => resolve(true), () => resolve(false), this.serviceName, "remove", [service, key]));
	}
};

module.exports = SecureKeyStore;

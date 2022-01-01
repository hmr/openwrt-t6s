'use strict';
'require form';
'require network';
'require tools.widgets as widgets';

network.registerPatternVirtual(/^t6s-.+$/);
network.registerErrorCode('AFTR_DNS_FAIL', _('Unable to resolve AFTR host name'));

return network.registerProtocol('t6s', {
	getI18n: function() {
		return _('Transix static IPv4(t6s)');
	},

	getIfname: function() {
		return this._ubus('l3_device') || 't6s-%s'.format(this.sid);
	},

	getOpkgPackage: function() {
		return 't6s';
	},

	isFloating: function() {
		return true;
	},

	isVirtual: function() {
		return true;
	},

	getDevices: function() {
		return null;
	},

	containsDevice: function(ifname) {
		return (network.getIfnameOf(ifname) == this.getIfname());
	},

	renderFormOptions: function(s) {
		var o;

		o = s.taboption('general', form.Value, 'ipaddr', _('Static IPv4 address'), _('IPv4 address assigned by ISP'));
		o.rmempty  = false;
		o.datatype = 'ipaddr("nomask")';

		o = s.taboption('general', form.Value, 'peeraddr', _('Remote IPv6 address'), _('IPv6 address of the static IP tunnel endpoint unit'));
		o.rmempty  = false;
		o.datatype = 'or(hostname,ip6addr("nomask"))';

		o = s.taboption('general', form.Value, 'ip6addr', _('Local IPv6 address'), _('Your IPv6 prefix (e.g. "2001:db8:100:200") + Interface ID (e.g. "::feed")'));
		o.datatype = 'ip6addr("nomask")';
		o.load = function(section_id) {
			return network.getWAN6Networks().then(L.bind(function(nets) {
					if (Array.isArray(nets) && nets.length)
							this.placeholder = nets[0].getIP6Addr();
					return form.Value.prototype.load.apply(this, [section_id]);
			}, this));
		};

		o = s.taboption('general', form.Value, 'upd_uri', _('Update server URI'), _('URI of update server'));
		o.rmempty  = true;
		o.datatype = 'string';
		o.load = function(section_id) {
			this.placeholder = "http://update.transix.jp/request";
			return form.Value.prototype.load.apply(this, [section_id]);
		};

		o = s.taboption('general', form.Value, 'upd_username', _('Update server username'), _(''));
		o.rmempty  = true;
		o.datatype = 'string';

		o = s.taboption('general', form.Value, 'upd_password', _('Update server password'), _(''));
		o.rmempty  = true;
		o.datatype = 'password';

		o = s.taboption('advanced', widgets.NetworkSelect, 'tunlink', _('Tunnel Link'));
		o.nocreate = true;
		o.exclude  = s.section;

		o = s.taboption('advanced', form.ListValue, 'encaplimit', _('Encapsulation limit'));
		o.rmempty  = false;
		o.default  = 'ignore';
		o.datatype = 'or("ignore",range(0,255))';
		o.value('ignore', _('ignore'));
		for (var i = 0; i < 256; i++)
			o.value(i);

		o = s.taboption('advanced', form.Value, 'mtu', _('Use MTU on tunnel interface'));
		o.placeholder = '1280';
		o.datatype    = 'max(9200)';
	}
});

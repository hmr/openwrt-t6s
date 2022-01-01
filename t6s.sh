#!/bin/sh
# t6s.sh - IPv4-in-IPv6 tunnel backend for Transix static IPv4 service
# Copyright (c) 2013 OpenWrt.org
# Copyright (c) 2021 Hatt Maru

# DEBUG
echo "$0 starts."
echo "args: $#"
echo "\$0: $0"
echo "\$1: $1"
echo "\$2: $2"
echo "\$3: $3"
echo "\$4: $4"

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. /lib/functions/network.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

# DEBUG
dbg_print_args(){
	local arg
	local cnt=1
	echo "num of args: $#"
	for arg in "$@"
	do
		echo "arg${cnt}: ${arg}"
		cnt=$((cnt+1))
	done
}

proto_t6s_setup() {
	# DEBUG
	echo "Entering proto_t6s_setup()"
	dbg_print_args "$@"

	local cfg="$1"
	local iface="$2"
	local link="t6s-$cfg"
	local remoteip6

	local         mtu ttl peeraddr ip6addr ipaddr tunlink zone weakif encaplimit wanif upd_uri upd_username upd_password
	json_get_vars mtu ttl peeraddr ip6addr ipaddr tunlink zone weakif encaplimit wanif upd_uri upd_username upd_password

	[ -z "$peeraddr" ] && {
		proto_notify_error "$cfg" "MISSING_ADDRESS"
		proto_block_restart "$cfg"
		return
	}

	( proto_add_host_dependency "$cfg" "::" "$tunlink" )

	remoteip6=$(resolveip -6 "$peeraddr")
	if [ -z "$remoteip6" ]; then
		sleep 3
		remoteip6=$(resolveip -6 "$peeraddr")
		if [ -z "$remoteip6" ]; then
			proto_notify_error "$cfg" "AFTR_DNS_FAIL"
			return
		fi
	fi

	for ip6 in $remoteip6; do
		peeraddr=$ip6
		break
	done

	[ -z "$ip6addr" ] && {
		wanif="$tunlink"
		if [ -z "$wanif" ] && ! network_find_wan6 wanif; then
			proto_notify_error "$cfg" "NO_WAN_LINK"
			return
		fi

		if ! network_get_ipaddr6 ip6addr "$wanif"; then
			[ -z "$weakif" ] && weakif="lan"
			if ! network_get_ipaddr6 ip6addr "$weakif"; then
				proto_notify_error "$cfg" "NO_WAN_LINK"
				return
			fi
		fi
	}

	# DEBUG
	local varname
	for varname in cfg iface link remoteip6 mtu ttl peeraddr ip6addr ipaddr tunlink zone wanif weakif encaplimit upd_uri upd_username upd_password
	do
		eval "echo \"${varname}=\${${varname}}\""
	done

	# Try to get WAN6 device
	local net_if6
	if [ -z "${wanif}" ]; then
		network_find_wan6 net_if6
		network_get_physdev wanif "${net_if6}"
		echo "wanif=${wanif}"
	fi
	# Try to guess WAN6 device
	if [ -z "${wanif}" ]; then
		# [ -z "${wanif}" ] && wanif=$(route -n -A inet6 | grep 'UG' | head -n 1 | awk '{print $7}')
		[ -z "${wanif}" ] && wanif=$(ip -6 route show | grep 'default' | head -n 1 | awk '{print $7}')
		echo "wanif=${wanif}(guessed from default route)" # DEBUG
	fi

	# Add IPv6 interface id address to WAN device
	if [ -n "${wanif}" ] && [ -n "${ip6addr}" ]; then
		# FIXME: Adhoc!
		if ! ip -6 address show dev "${wanif}" | grep -q "${ip6addr}"; then
			if ! ip -6 address add "${ip6addr}/64" dev "${wanif}"; then
				proto_notify_error "$cfg" "NO_IF_ADDR"
				return
			else
				echo "Interface ID was added to ${wanif}. Wait for 15 secs to avoid error message storm."
				sleep 15
			fi
		fi
	fi

	# Device setup
	proto_init_update "$link" 1
	proto_add_ipv4_route "0.0.0.0" 0
	proto_add_ipv4_address "$ipaddr" "" "" ""  # <IP address> [mask] [broadcast] [ptp]

	proto_add_tunnel
	json_add_string mode ipip6
	json_add_int mtu "${mtu:-1280}" # 1280 is copied from dslite.sh
	json_add_int ttl "${ttl:-64}"
	json_add_string local "$ip6addr"
	json_add_string remote "$peeraddr"
	[ -n "$tunlink" ] && json_add_string link "$tunlink"
	json_add_object "data"
	[ -n "$encaplimit" ] && json_add_string encaplimit "$encaplimit"
	json_close_object
	proto_close_tunnel

	# FIXME: Adhoc: Isn't this part necessary because firewall setting's "Masquerading" is better way?
	# zone="wan"
	# proto_add_data
	#   [ -n "$zone" ] && json_add_string zone "$zone"
	#
	#   json_add_array firewall
	#     json_add_object ""
	#     json_add_string type nat
	#     json_add_string target zone_wan_postrouting
	#     json_close_object
	#   json_close_array
	# proto_close_data

	proto_send_update "$cfg"

	if [ -n "${upd_uri}" ] && [ -n "${upd_username}" ]  && [ -n "${upd_password}" ]; then
		if which "uclient-fetch" > /dev/null 2>&1; then
			echo "use uclient-fetch"
			auth_bin="uclient-fetch"
			auth_arg="-6 --quiet -O -"
		elif which "wget" > /dev/null 2>&1; then
			echo "use wget"
			auth_bin="wget"
			auth_arg="-6 --quiet -O -"
		elif which "curl" > /dev/null 2>&1; then
			echo "use curl"
			auth_bin="curl"
			auth_arg="-6 --silent -o -"
		fi
		echo "Authenticate at update server:"
		echo "upd_uri=${upd_uri}"
		echo "username=${upd_username}"
		echo "password=${upd_password}"

		local result
		result="$(${auth_bin} ${auth_arg} "${upd_uri}?username=${upd_username}&password=${upd_password}")"

		if [ "${result}" = "OK" ]; then
			echo "Successfully updated"
		else
			echo "Update failed!"
		fi
	fi
	echo "Leaving proto_t6s_setup()"
}

proto_t6s_teardown() {
	echo "Entering proto_t6s_teardown()"
	dbg_print_args "$@"

	local cfg="$1"

	# Try to set WAN6 device
	local wanif net_if6
	if [ -z "${wanif}" ]; then
		network_find_wan6 net_if6
		network_get_physdev wanif "${net_if6}"
	fi
	[ -z "${wanif}" ] && wanif=$(route -n -A inet6 | grep 'UG' | awk '{print $7}')

	# DEBUG
	echo "wanif=${wanif}"
	echo "ip6addr=${ip6addr}"

	# Delete Interface ID from WAN device
	if [ -n "${wanif}" ] && [ -n "${ip6addr}" ]; then
		if ip address show dev "${wanif}" | grep -q "${ip6addr}"; then
			ip -6 address del "${ip6addr}" dev "${wanif}"
		fi
	fi

	echo "Leaving proto_t6s_teardown()"
}

proto_t6s_init_config() {
	echo "Entering proto_t6s_init_config()"
	dbg_print_args "$@"

	no_device=1
	available=1

	proto_config_add_string "ipaddr"
	proto_config_add_string "ip6addr"
	proto_config_add_string "peeraddr"
	proto_config_add_string "tunlink"
	proto_config_add_int "mtu"
	proto_config_add_int "ttl"
	proto_config_add_string "encaplimit"
	proto_config_add_string "zone"
	proto_config_add_string "weakif"
	proto_config_add_string "wanif"
	proto_config_add_string "upd_uri"
	proto_config_add_string "upd_username"
	proto_config_add_string "upd_password"

	echo "Leaving proto_t6s_init_config()"
}

[ -n "$INCLUDE_ONLY" ] || {
        add_protocol t6s
}

# vim: set ts=4

#!/bin/bash
# vim: ft=sh ts=4 :

# iptSetLog.sh
# Insert/delete LOG rules into all the tables.

# Origin: 2021-12-05 by hmr

# Settings
[ -z "${DRY_RUN}" ] && DRY_RUN=0
IPTABLES_BIN="$(which iptables)"
IPTABLES_SAVE_BIN="$(which iptables-save)"

# Initialize
[ "${DRY_RUN}" = "1" ] && echo "DRY-RUN mode"
if echo -n "$0" | grep -q "Del"; then
	IPT_MODE="-D"
	echo -n "Deleting "
else
	IPT_MODE="-I"
	echo -n "Appending "
fi
echo "LOG filter(s)."

LOG_OPTION="--log-level debug --log-tcp-sequence --log-tcp-options --log-ip-options --log-uid"

LIMIT="-m limit --limit 100/sec"
COMMENT="-m comment --comment iptLogSet"

#G_CONDITIONS=("-d 172.16.22.11" "-s 172.16.22.11")
G_CONDITIONS=("-d li1870-224.members.linode.com" "-s li1870-224.members.linode.com")

# Functions
function do_iptables() {
	local _chain=$1
	local _table=$2
	local _cond=$3
	[ -z "${_chain}" ] && return
	[ -z "${_table}" ] && _table="filter"

	# Shorten table name for LOG prefix
	local _table_prefix
	case $_table in
		raw )		_table_prefix="R";;
		nat )		_table_prefix="N";;
		filter )	_table_prefix="F";;
		mangle )	_table_prefix="M";;
		security )	_table_prefix="S";;
		* )			_table_predix="?";;
	esac

	# Shorten chain name for LOG prefix
	local _chain_prefix
	_chain_prefix="${_chain:0:24}"

	# Upper conversion
	declare -u _log_prefix
	case "$_chain" in
		PREROUTING | FORWARD | INPUT | OUTPUT | POSTROUTING )
			_log_prefix="<${_chain_prefix}>(${_table_prefix})"
			;;
		*)
			_log_prefix="[${_chain_prefix}](${_table_prefix})"
			;;
	esac

	# Up to 27 characters
	_log_prefix="${_log_prefix:0:27}: "

	if [ "$DRY_RUN" = "1" ]; then
		echo "${IPTABLES_BIN}" -t "${_table}" "${IPT_MODE}" "${_chain}" "${_cond}" "${LIMIT}" -j LOG "${LOG_OPTION}" --log-prefix \""${_log_prefix}"\" "${COMMENT}"
	else
		"${IPTABLES_BIN}" -t "${_table}" "${IPT_MODE}" "${_chain}" "${_cond}" ${LIMIT} -j LOG ${LOG_OPTION} --log-prefix "${_log_prefix}" ${COMMENT}
	fi
}

function modify_chain() {
	declare -n _table=$1
	declare -n _chains=$2
	declare -n _conditions=$3

	local _chain _condition
	for _chain in "${_chains[@]}"
	do
		for _condition in "${_conditions[@]}"
		do
			echo "Table: ${_table} Chain:${_chain}: Condirion: ${_condition}"
			do_iptables "${_chain}" "${_table}" "${_condition}"
		done
		echo
	done
}

function get_chains_all() {
	local _table=$1
	declare -a _chains

	[ -z ${_table} ] && return

	declare -a _tmp_filters=($(${IPTABLES_SAVE_BIN} -t ${_table} | grep "^:" | sed -e 's/^://g' | cut -d " " -f 1))
	[ -z "${_tmp_filters}" ] && return

	echo "${_tmp_filters[@]}"
}


# Table: nat
function modify_nat() {
	local table="nat"
	declare -a chains conditions

	# Normal
	#chains=(prerouting_lan_rule prerouting_wan_rule postrouting_lan_rule postrouting_wan_rule)
	# Paranoiac
	#chains=(postrouting_rule prerouting_rule zone_lan_postrouting zone_lan_prerouting zone_wan_postrouting zone_wan_prerouting)
	# Super Paranoiac
	#chains+=(PREROUTING INPUT OUTPUT POSTROUTING)

	[ -z "${chains}" ] && chains=($(get_chains_all ${table}))

	#conditions=("-d li1870-224.members.linode.com" "-s li1870-224.members.linode.com")
	conditions=("${G_CONDITIONS[@]}")
	
	modify_chain table chains conditions
}

# Table: filter
function modify_filter() {
	local table="filter"
	declare -a chains conditions

	# Normal
	#chains=(forwarding_rule forwarding_lan_rule forwarding_wan_rule input_lan_rule input_wan_rule output_lan_rule output_wan_rule)
	# Paranoiac
	#chains+=(output_rule reject syn_flood zone_lan_dest_ACCEPT zone_lan_forward zone_lan_input zone_lan_output zone_lan_src_ACCEPT zone_wan_dest_ACCEPT zone_wan_dest_REJECT zone_wan_forward zone_wan_input zone_wan_output zone_wan_src_REJECT)
	# Super Paranoiac
	#chains+=(INPUT FORWARD OUTPUT)

	[ -z "${chains}" ] && chains=($(get_chains_all ${table}))

	#conditions=("-d li1870-224.members.linode.com" "-s li1870-224.members.linode.com")
	conditions=("${G_CONDITIONS[@]}")

	modify_chain table chains conditions
}

# Table: raw 
function modify_raw() {
	local table="raw"
	declare -a chains conditions

	[ -z "${chains}" ] && chains=($(get_chains_all ${table}))

	#conditions=("-d li1870-224.members.linode.com" "-s li1870-224.members.linode.com")
	conditions=("${G_CONDITIONS[@]}")
	
	modify_chain table chains conditions
}

# Table: mangle
function modify_mangle() {
	local table="mangle"
	declare -a chains conditions

	[ -z "${chains}" ] && chains=($(get_chains_all ${table}))

	#conditions=("-d li1870-224.members.linode.com" "-s li1870-224.members.linode.com")
	conditions=("${G_CONDITIONS[@]}")
	
	modify_chain table chains conditions
}

# Table: security
function modify_security() {
	local table="security"
	declare -a chains conditions

	[ -z "${chains}" ] && chains=($(get_chains_all ${table}))

	#conditions=("-d li1870-224.members.linode.com" "-s li1870-224.members.linode.com")
	conditions=("${G_CONDITIONS[@]}")
	
	modify_chain table chains conditions
}

echo "---------------------------------------------------------------------------------------------"
modify_raw
echo "---------------------------------------------------------------------------------------------"
modify_mangle
echo "---------------------------------------------------------------------------------------------"
modify_nat
echo "---------------------------------------------------------------------------------------------"
modify_filter


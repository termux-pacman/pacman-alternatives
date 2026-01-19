#!@BASHPATH@

set -e

# pacman-alternatives system variable
if [[ -z "${PA_RUN_IN_ALPM_HOOKS}" || ("${PA_RUN_IN_ALPM_HOOKS}" != "true" && "${PA_RUN_IN_ALPM_HOOKS}" != "false") ]]; then
	PA_RUN_IN_ALPM_HOOKS=false
fi
PA_DEF_SYSDIR="@SYSDIR@"
PA_DEF_PREFIX="@PREFIX@"
PA_DEF_ALTER_FILES_PATH="@ALTER_FILES_PATH@"
PA_DEF_ENABLED_ALTERS_PATH="@ENABLED_ALTERS_PATH@"
_pa_sysdir="${PA_SYSDIR:="${PA_DEF_SYSDIR}"}"
_pa_prefix="${PA_PREFIX:="${PA_DEF_PREFIX}"}"
_pa_alter_files_path="${PA_ALTER_FILES_PATH:="${PA_DEF_ALTER_FILES_PATH}"}"
_pa_enabled_alters_path="${PA_ENABLED_ALTERS_PATH="${PA_DEF_ENABLED_ALTERS_PATH}"}"
if [ "${_pa_alter_files_path::1}" != "/" ]; then
	_pa_alter_files_path="${_pa_prefix}/${_pa_alter_files_path}"
fi
if [ "${_pa_enabled_alters_path::1}" != "/" ]; then
	_pa_enabled_alters_path="${_pa_prefix}/${_pa_enabled_alters_path}"
fi

# pacman-alternatives system info
_pa_version="1.0.0-BETA"

# database
_pa_enabled_alt=()
_pa_selected_alt=()
_pa_static_selected_alt=()
_pa_non_integrity_alt=()

# style
_pa_bold=""
_pa_nostyle=""
_pa_blue=""
_pa_green=""
_pa_yellow=""
_pa_red=""

# system variable settings for internal work
_pa_nomessage=false
_pa_select_selected_alt=false
_pa_selfmode=false
_pa_noprogress=false
_pa_nowarning=false
_pa_noerror=false
_pa_only_group=false
_pa_only_name=false
_pa_norequire_alt=false
_pa_haserror=false
_pa_arg_is_altfile=false
_pa_progress_noret=false

# user variable settings / user options
_pa_needed=false
_pa_noconfirm=false
_pa_noghost=false
_pa_enable_select=false
_pa_reject_disable=false
_pa_reject_replace=false
_pa_disable_reject=false
_pa_disable_ghost=false
_pa_guery_check=false
_pa_query_groups=false
_pa_query_global_list=false
_pa_query_list=false
_pa_query_info=false
_pa_query_alters=false
_pa_query_alter_files=false
_pa_helpmode=false
_pa_automode=false
_pa_updatemode=false
_pa_overwrite=false

_pa_message() {
	! ${_pa_nomessage} && echo -ne "$1" >&2 || true
}

_pa_progress() {
	local now="$1" goal="$2"
	! ${_pa_noprogress} && _pa_message "${_pa_title_progress}(${now}/${goal}) ${3}${_pa_nostyle}$((! ${_pa_progress_noret} && ((now < goal))) && echo '\r' || echo '\n')" || true
}

_pa_header_standard() {
	echo -e "${_pa_title_header}${_pa_bold} $1${_pa_nostyle}"
}

_pa_info() {
	_pa_message "$(_pa_header_standard "$1")\n"
}

_pa_commit() {
	_pa_info "$1..."
}

_pa_warning() {
	! ${_pa_nowarning} && _pa_message "${_pa_yellow}${_pa_title_warning}${_pa_nostyle} $1\n" || true
}

_pa_error_message() {
	_pa_nomessage=false _pa_message "${_pa_red}${_pa_title_error}${_pa_nostyle} $1\n"
}

_pa_init_error() {
	_pa_error_message "$1"
	_pa_haserror=true
}

_pa_error() {
	_pa_error_message "$1"
	exit 1
}

_pa_nothing_to_do() {
	_pa_message "${_pa_title_progress:=" "}there is nothing to do\n"
	exit 0
}

_pa_merge_data() {
	local rows=${1}
	shift 1

	local goal=$((${#}-${#}/rows+1))
	local pi=$(((goal-1)/(rows-1)))
	while (($# >= ${goal})); do
		local index=1
		while ((${index} < ${goal})); do
			echo -ne "${!index}:"
			index=$((index+pi))
		done
		echo "${!goal}"
		shift 1
	done
}

_pa_check_dir_path() {
	[[ "${1::1}${1:((${#1}-1))}" = "//" && -d "${1}" ]]
	return $?
}

_pa_read_alter_file() {
	local i=1 goal=$# error=() result=() sysdir linkdir rootdir name group associations alter_path alter
	while (($# >= 1)); do
		_pa_progress "${i}" "${goal}" "reading alternative files"
		alter="${1}"
		i=$((i+1))
		shift 1

		if ${_pa_arg_is_altfile}; then
			alter_path="${alter}"
			name="$(basename ${alter%.*})"
			group=".*"
		else
			name="${alter##*:}"
			group="${alter%%:*}"
			if [ "${group}" = "*" ]; then
				group=".*"
			fi
			alter_path="${_pa_alter_files_path}/${name}.alt"
		fi

		associations=()
		if [[ "${name}" != "*" && ! -f "${alter_path}" ]]; then
			error+=("${group:=[unknown]}:${name}:notfound")
			continue
		fi
		local func=$(source ${alter_path}; declare -f | grep -E "(^| )alter_group_${group}( |\()" | awk '{printf $1 "|"}')
		for func in $(grep -EHo "(^| )(${func::-1})( |\()" ${alter_path} | sed 's|(||g; s|\.alt:|:|g'); do
			sysdir="${_pa_sysdir}"
			linkdir=""
			rootdir=""
			group="${func//*:alter_group_/}"
			alter_path="${func%%:*}"
			name="${alter_path##*/}"
			func="${func##*:}"
			if [[ " ${result[@]}" =~ " ${group}:${name}:" ]]; then
				continue
			fi
			result+=($(
				source ${alter_path}.alt
				${func}
				: "${linkdir:="${sysdir}"}"
				: "${rootdir:="${sysdir}"}"
				if [[ -z "${group}" || ! "${priority:=0}" =~ ^[0-9]+$ || \
					"$(sed 's/-//g; s/_//g' <<< "${group}${name}")" =~ [[:punct:]] || \
					"${group}${name}" =~ " " || \
					"$(grep -c '^.*$' <<< "${associations[@]} ${linkdir} ${rootdir}")" != "1" ]] || \
					grep -E "(//|:| )" <<< "${linkdir};${rootdir}" || \
					! _pa_check_dir_path "${linkdir}" || ! _pa_check_dir_path "${rootdir}" || \
					grep -Eq "(^|/|:| )(/|:| |$)" <<< "${associations[@]}" || \
					awk -v RS=' ' -v len="${#associations[@]}" '!a[$1]++ {b+=split($1, cache, ":")}
					END {
						if (len == length(a) && len*2 == b)
							exit 1
						else
							exit 0
					}' <<< "${associations[@]}"; then
					exit 1
				fi
				awk -v RS=" " \
					-v group="${group}" \
					-v name="${name}" \
					-v priority="${priority:=0}" \
					-v linkdir="${linkdir}" \
					-v rootdir="${rootdir}" \
					'{split($1,path,":"); print group ":" name ":" priority ":" linkdir path[1] ":" rootdir path[2]}' \
					<<< "${associations[@]}"
			)) || error+=("${group:=[unknown]}:${name}:syntax")
		done
	done
	tr ' ' '\n' <<< "${result[@]}"
	if ! ${_pa_noerror} && [ -n "${error}" ]; then
		local alt
		for i in ${error[@]}; do
			alt="${i%:*}"
			case "${i##*:}" in
				syntax) _pa_error_message "syntax error in alternative file: ${alt}";;
				notfound) _pa_error_message "alternative file not found: ${alt}"
			esac
		done
		exit 1
	fi
}

_pa_read_enabled_alters() {
	_pa_enabled_alt=($(for association in $(find "${_pa_enabled_alters_path}" -mindepth 1 -type f); do
		association="${association//${_pa_enabled_alters_path}\//}"
		awk -v association="${association//\//:}" -F "=" '{if ($1 == "association") print association ":" $2}' "${_pa_enabled_alters_path}/${association}"
	done))
}

_pa_read_selected_alters() {
	_pa_selected_alt=($(find "${_pa_enabled_alters_path}" -type l -exec readlink -fn {} \; -printf ':%f\n' | sed "s|${_pa_enabled_alters_path}/||g; s|:.*:select:|:|g; s|/|:|g"))
}

_pa_get_selected_alters() {
	grep -E ${@} "^($(tr ' ' '|' <<< "${_pa_selected_alt[@]%:*}")):" || true
}

_pa_get_enabled_alter() {
	local i=1 goal=$# notfound=() list=$(tr ' ' '\n' <<< "${_pa_enabled_alt[@]}") result=() type="enabled"
	if ${_pa_select_selected_alt}; then
		list=$(_pa_get_selected_alters <<< "${list}")
		type="selected"
	fi
	while (($# >= 1)); do
		_pa_progress "${i}" "${goal}" "getting ${type} alternatives"
		result+=($(grep "^${1//\*/\.*}:" <<< "${list}")) || notfound+=("${1}")
		i=$((i+1))
		shift 1
	done
	tr ' ' '\n' <<< "${result[@]}" | sort -u
	if ! ${_pa_noerror} && [ -n "${notfound}" ]; then
		for i in ${notfound[@]}; do
			_pa_error_message "${type} alternative not found: ${i}"
		done
		exit 1
	fi
}

_pa_return_enabled_alter() {
	tr ' ' '\n' <<< "${_pa_enabled_alt[@]}" | grep -Ev "^($(tr ' ' '|' <<< "${_pa_non_integrity_alt[@]}"))$"
}

_pa_chmod_alters() {
	local paths=($(find "${_pa_enabled_alters_path}" -mindepth 1 -type f -o -type d))
	[ -z "${paths}" ] || chmod ${1} ${paths[@]}
}

_pa_get_checksum_alter() {
	sha256sum "${1}" | awk '{print "checksum=" $1}'
}

_pa_check_checksum_alter() {
	awk -F '=' -v alt_file="${_pa_alter_files_path}/${1##*:}.alt" '{ if ($1 == "checksum") { print $2, alt_file } else {exit} }' "${_pa_enabled_alters_path}/${1//://}:"* | sha256sum -c --status 2>/dev/null
	return $?
}

_pa_check_alter_data_integrity() {
	local i=0 goal="$#"
	while (($# >= 1)); do
		_pa_progress "$((i+1))" "${goal}" "checking alternative data integrity"
		awk -v i="${i}" '{
			if (!(split($0, data, ":") == 5 &&
				data[1] != "" && gsub("-", "", data[1])+1 && gsub("_", "", data[1])+1 && data[1] !~ "[[:punct:]]" &&
				data[2] != "" && gsub("-", "", data[2])+1 && gsub("_", "", data[2])+1 && data[2] !~ "[[:punct:]]" &&
				int(data[3]) == data[3] &&
				substr(data[4], 1, 1) == "/" &&
				substr(data[5], 1, 1) == "/" &&
				substr(data[4], length(data[4]), 1) != "/" &&
				substr(data[5], length(data[5]), 1) != "/"))
				print i
		}' <<< "${1}"
		i=$((i+1))
		shift 1
	done
	exit 1
}

_pa_check_existence_root_path() {
	local i=0 goal=$((${#}/2+1)) list="${@}"
	if [ "${operation:-}" = "enable" ]; then
		list+=" $(_pa_return_enabled_alter | awk -F ':' '{printf $4 " "}')"
	fi
	list="$(tr ' ' '\n' <<< "${list}")"
	while (($# >= ${goal})); do
		_pa_progress "$((i+1))" "$((goal-1))" "checking root paths for existence"
		if [ ! -f "${!goal}" ] && ! (($(grep -c "^${!goal}$" <<< "${list}") > 1)); then
			echo $i
		fi
		i=$((i+1))
		shift 1
	done
}

_pa_check_existence_link_path() {
	local i=0 goal="$#" list="$(tr ' ' '\n' <<< "${@} $(_pa_return_enabled_alter | _pa_get_selected_alters | awk -F ':' '{print $4}')")"
	while (($# >= 1)); do
		_pa_progress "$((i+1))" "${goal}" "checking link paths for existence"
		if [ -f "${1}" ] && ! (($(grep -c "^${1}$" <<< "${list}") > 1)); then
			echo $i
		fi
		i=$((i+1))
		shift 1
	done
	exit 1
}

_pa_check_conflict_link_path() {
	local i=0 goal=$((${#}/2+1))
	local d_associations="$(_pa_merge_data 2 ${@} | sort -u)"
	local e_associations="$(_pa_return_enabled_alter | awk -F ':' '!a[$1 ":" $4]++ {print $1 ":" $4}' | grep -Ev "^($(awk -F ':' '!a[$1]++ {print $1}' <<< "${d_associations}" | paste -sd '|')):")"
	while (($# >= ${goal})); do
		_pa_progress "$((i+1))" "$((goal-1))" "checking link paths for conflicts"
		if (($(grep -c ":${!goal}$" <<< "${d_associations}") > 1)) || grep -q ":${!goal}$" <<< "${e_associations}"; then
			echo $i
		fi
		i=$((i+1))
		shift 1
	done
}

_pa_check_conflict_enabled_alter() {
	local i=0 goal=$((${#}/2+1)) list="$(_pa_merge_data 2 ${@} | sort -u)" old=""
	while (($# >= ${goal})); do
		_pa_progress "$((i+1))" "$((goal-1))" "checking enabled alternatives for conflicts"
		local now="${1}:${!goal}"
		if (($(grep -c "^${1}:" <<< "${list}") > 1)) && [ "${now}" != "${old}" ]; then
			echo $i
			old="${now}"
		fi
		i=$((i+1))
		shift 1
	done
}

_pa_check_valid_link_path() {
	local i=0 goal="$#"
	while (($# >= 1)); do
		_pa_progress "$((i+1))" "${goal}" "checking link paths for validity"
		if [ ! -d "${1%/*}" ]; then
			echo $i
		fi
		i=$((i+1))
		shift 1
	done
}

_pa_check_dependent_alter() {
	local i=0 goal="$#" list="$(_pa_return_enabled_alter)"
	if [ "${operation:-}" = "reject" ] && ! ${_pa_reject_disable}; then
		list="$(_pa_get_selected_alters <<< "${list}")"
	fi
	list="$(awk -F ':' '{print $4 ":" $5}' <<< "${list}" | grep -Ev "^($(tr ' ' '|' <<< "${@}")):")"
	while (($# >= 1)); do
		_pa_progress "$((i+1))" "${goal}" "checking alternative for dependencies"
		if grep -q ":${1}$" <<< "${list}"; then
			echo $i
		fi
		i=$((i+1))
		shift 1
	done
}

_pa_check_duplicate_root_path() {
	local args=($(_pa_merge_data 3 ${@}))
	local i=0 goal=$((${#args[@]})) list="$(_pa_return_enabled_alter)"
	while ((${i} < ${goal})); do
		_pa_progress "$((i+1))" "${goal}" "checking root paths for duplicate"
		if grep -v "^${args[${i}]%:*}:" <<< "${list}" | grep -q "^${args[${i}]%%:*}:.*:${args[${i}]##*:}$"; then
			echo $i
		fi
		i=$((i+1))
		shift 1
	done
}

_pa_check_alter_by_algorithm() {
	local alg="${1}" message="${2}"
	shift 2

	local i=0 goal=$((${#}/2+1)) old_alt="" alt
	while (($# >= ${goal})); do
		_pa_progress "$((i+1))" "$((goal-1))" "${message}"
		alt="${1}:${!goal}"
		if [ "${alt}" != "${old_alt}" ]; then
			if eval "${alg}"; then
				echo $i
			fi
			old_alt="${alt}"
		fi
		i=$((i+1))
		shift 1
	done
}

_pa_check_selected_alter() {
	_pa_check_alter_by_algorithm '[[ " ${_pa_selected_alt[@]}" =~ " ${alt}:" ]]' \
		'checking for selected alternatives' \
		${@}
}

_pa_check_alter_belong_pkg() {
	_pa_check_alter_by_algorithm 'grep -q "^${_pa_alter_files_path:1}/${!goal}.alt$" "${_pa_pacman_dbpath}/local/"*"/files"' \
		'checking alternative files for belong to pkgs' \
		${@}
}

_pa_check_enabled_alter() {
	_pa_check_alter_by_algorithm '[[ " ${_pa_enabled_alt[@]}" =~ " ${alt}:" ]]' \
		'checking for enabled alternatives' \
		${@}
}

_pa_check_alt() {
	_pa_check_alt_eval() {
		if [ "${operation}" = "query" ]; then
			local _pa_noprogress=true
		fi
		eval "local result_check_${1}=\$(_pa_nomessage=${_pa_noprogress} _pa_check_${1} ${2})
		if [ -n \"\${result_check_${1}}\" ]; then
			_pa_error_message \"${3}\"
			for i in \${result_check_${1}}; do
				_pa_message \"\${list_group[\$i]}:\${list_name[\$i]}: ${4}\n\"
				if [[ ! \" \${list_index_issue[@]} \" =~ \" \${i} \" ]]; then
					list_index_issue+=(\${i})
				fi
			done
			if [ \"\${operation}\" != \"query\" ]; then
				exit 1
			fi
		fi"
	}

	local operation="$1"
	shift 1
	case "${operation}" in
		"enable"|"select"|"disable"|"reject"|"query"|"install"|"uninstall");;
		*) _pa_error "internal error: unknown operation '${operation}' for _pa_check_alt"
	esac

	local i
	if [ "${operation}" != "query" ]; then
		local result_check_alter_data_integrity=$(_pa_check_alter_data_integrity ${@})
		if [ -n "${result_check_alter_data_integrity}" ]; then
			if [[ "${operation}" = "enable" || "${operation}" = "select" || "${operation}" = "install" ]]; then
				_pa_error_message "alternative data integrity problem"
			else
				_pa_warning "found alternative data with an integrity problem, will be ignored"
			fi
			for i in ${result_check_alter_data_integrity}; do
				i=$((${i}+1))
				_pa_non_integrity_alt+=("${!i}")
				_pa_message "${!i}\n"
			done
			if [[ "${operation}" = "enable" || "${operation}" = "select" ]]; then
				exit 1
			fi
		fi
	fi

	local list_group=() list_name=() list_priority=() list_link_path=() list_root_path=() list_index_issue=()
	while (($# >= 1)); do
		eval "$(awk -F ':' '{
			print "list_group+=(\"" $1 "\")"
			print "list_name+=(\"" $2 "\")"
			print "list_priority+=(\"" $3 "\")"
			print "list_link_path+=(\"" $4 "\")"
			print "list_root_path+=(\"" $5 "\")"
		}' <<< "${1}")"
		shift 1
	done
	if [[ "${operation}" != "query" && -n "${result_check_alter_data_integrity}" ]]; then
		for i in ${result_check_alter_data_integrity}; do
			unset list_{group,name,priority,{link,root}_path}[${i}]
		done
		list_group=(${list_group[@]})
		if [ "${#list_group[@]}" = "0" ]; then
			_pa_warning "all alternative data have integrity problems, skip checking to remove corrupted data"
			return
		fi
		list_name=(${list_name[@]})
		list_priority=(${list_priority[@]})
		list_link_path=(${list_link_path[@]})
		list_root_path=(${list_root_path[@]})
	fi

	if [[ "${operation}" = "enable" || "${operation}" = "select" || "${operation}" = "query" || "${operation}" = "install" ]]; then
		_pa_check_alt_eval existence_root_path '${list_link_path[@]} ${list_root_path[@]}' 'invalid root paths' \
			'${list_root_path[$i]} not found for ${list_link_path[$i]##*/}'
		_pa_check_alt_eval valid_link_path '${list_link_path[@]}' 'not valid link paths' \
			'${list_link_path[$i]%/*} not valid'
	fi

	case "${operation}" in
		"enable"|"query")
		_pa_check_alt_eval duplicate_root_path '${list_group[@]} ${list_name[@]} ${list_root_path[@]}' 'duplicate root paths' \
			'${list_root_path[$i]} duplicate'
		_pa_check_alt_eval conflict_link_path '${list_group[@]} ${list_link_path[@]}' 'alternative conflicts' \
			'${list_link_path[$i]} conflicts'
		;;

		"select")
		if ! ${_pa_overwrite}; then
			_pa_check_alt_eval existence_link_path '${list_link_path[@]}' 'link path conflicts' \
				'${list_link_path[$i]} exists in filesystem'
		fi
		_pa_check_alt_eval conflict_enabled_alter '${list_group[@]} ${list_name[@]}' 'enabled alternative conflicts' 'conflicts'
		;;

		"disable")
		if ! ${_pa_disable_reject}; then
			_pa_check_alt_eval selected_alter '${list_group[@]} ${list_name[@]}' 'impossible disable selected alternative' 'selected'
		fi
		;;

		"uninstall")
		_pa_check_alt_eval enabled_alter '${list_group[@]} ${list_name[@]}' 'impossible delete alternative file when its enabled' 'enabled'
		;;
	esac

	if [[ "${operation}" = "disable" || "${operation}" = "reject" ]]; then
		_pa_check_alt_eval dependent_alter '${list_link_path[@]}' 'alternative presents dependency' 'needed'
	elif [[ "${operation}" = "install" || "${operation}" = "uninstall" ]]; then
		_pa_check_alt_eval alter_belong_pkg '${list_group[@]} ${list_name[@]}' "impossible ${operation} alternative file belongs to pkg" 'belongs'
	elif [ "${operation}" = "query" ]; then
		echo ${list_index_issue[@]}
	fi
}

_pa_get_mode_by_selected_alt() {
	local len="${#_pa_static_selected_alt[@]}"
	[ "${len}" = "0" ] && return 1
	awk -F ':' -v RS=" " -v gr="${1}" -v len="${len}" '{if ($1 == gr) {print $3; exit 0} else if (NR == len) {exit 1} }' <<< "${_pa_static_selected_alt[@]}"
}

_pa_action_association() {
	local operation="$1"
	shift 1
	case "${operation}" in
		"enable"|"update"|"disable"|"install"|"remove"|"query");;
		*) _pa_error "internal error: unknown operation '${operation}' for _pa_action_association"
	esac

	local old_association i goal args=$(tr ' ' '\n' <<< "$@") mode=$(${_pa_automode} && echo "auto" || echo "manual") group name priority link_path root_path

	while (($# >= 1)); do
		eval "$(awk -F ':' '{
			print "group=" $1
			print "name=" $2
			print "priority=" $3
			print "link_path=" $4
			print "root_path=" $5
		}' <<< "${1}")"

		local alter="${group}:${name}"
		local association="${group}/${name}:${priority}"
		local group_path="${_pa_enabled_alters_path}/${group}"
		local association_path="${_pa_enabled_alters_path}/${association}"

		if [ "${old_association}" != "${association}" ]; then
			i=1
			goal=$(grep -c "^${alter}:" <<< "${args}")
			if ${_pa_selfmode}; then
				mode=$(_pa_get_mode_by_selected_alt "${group}" || echo "${mode}")
			fi
		fi

		case "${operation}" in
			"enable"|"update")
			_pa_progress "${i}" "${goal}" "${operation::-1}ing associations for ${alter}"
			if [ "${old_association}" != "${association}" ]; then
				if [ ! -d "${group_path}" ]; then
					mkdir -p "${group_path}"
				else
					find "${group_path}" -type f -name "${name}:*" -delete
				fi
				_pa_get_checksum_alter "${_pa_alter_files_path}/${name}.alt" > "${association_path}"
			fi
			echo "association=${link_path}:${root_path}" >> "${association_path}"
			;;

			"install")
			_pa_progress "${i}" "${goal}" "installing associations for ${alter}"
			if [ "${old_association}" != "${association}" ]; then
				local selected=$(tr ' ' '\n' <<< "${_pa_selected_alt[@]%:*}" | grep "^${group}:")
				if [ -n "${selected}" ]; then
					_pa_nomessage=true _pa_action_association "remove" $(_pa_nomessage=true _pa_get_enabled_alter ${selected})
				fi
				ln -sr "${association_path}" "${group_path}/select:${mode}"
			fi
			ln -s $(${_pa_overwrite} && echo "-f") "${root_path}" "${link_path}"
			;;

			"disable")
			_pa_progress "${i}" "${goal}" "disabling associations for ${alter}"
			if [ "${old_association}" != "${association}" ]; then
				rm -f "${association_path}"
			fi
			;;

			"remove")
			_pa_progress "${i}" "${goal}" "removing associations for ${alter}"
			if [ "${old_association}" != "${association}" ]; then
				rm -f "${group_path}/select:"*
			fi
			if [[ ! " ${_pa_non_integrity_alt[@]} " =~ " ${1} " ]]; then
				rm -f "${link_path}"
			fi
			;;

			"query")
			if [[ ! " ${_pa_non_integrity_alt[@]} " =~ " ${1} " ]]; then
				if [[ "${old_association}" != "${association}" && "${mode}" = "auto" && \
					"$(_pa_return_enabled_alter | awk -F ':' -v group="${group}" '{if ( group == $1 && int($3) == $3 && i < $3) i = $3} END {print i}')" != "${priority}" ]]; then
					_pa_error_message "selected alternative ${alter} does not have maximum priority"
					echo "${alter}"
				fi
				if ! [[ -L "${link_path}" && "$(readlink ${link_path})" = "${root_path}" ]]; then
					_pa_error_message "problem with link: ${link_path}"
					echo "$alter}"
				fi
			fi
			;;
		esac

		old_association="${association}"
		i=$((i+1))
		shift 1
	done

	case "${operation}" in
		"select"|"reject") _pa_read_selected_alters;;
	esac

	if [ "${operation}" = "disable" ]; then
		find "${_pa_enabled_alters_path}/" -mindepth 1 -type d -empty -delete
	fi
}

_pa_choose_alt_by_priority() {
	local group="${1}" alt1 alt2
	local high="${2##*:}" low="${3#*:}"
	if (("${high}" > "${low}")); then
		return 0
	elif (("${high}" == "${low}")); then
		alt1="${_pa_enabled_alters_path}/${group}/${2}"
		alt2="${_pa_enabled_alters_path}/${group}/${3}"
		if ! [[ -f "${alt1}" && -f "${alt2}" ]]; then
			alt1="${_pa_alter_files_path}/${2%:*}.alt"
			alt2="${_pa_alter_files_path}/${3%:*}.alt"
			if [ ! -f "${alt1}" ]; then
				return 1
			elif [ ! -f "${alt2}" ]; then
				return 0
			fi
		fi
		if (($(date -r "${alt1}" "+%s%N") < $(date -r "${alt2}" "+%s%N"))); then
			return 0
		fi
	fi
	return 1
}

_pa_select_alt() {
	local list="$(tr ' ' '\n' <<< "${@}" | sort -u)" alt alts alti alti_s mode=$(${_pa_automode} && echo "auto" || echo "manual") ghost_alt=()
	for alt in $(awk -F ':' '!a[$1]++ {print $1}' <<< "${list}"); do
		alts=($(grep "^${alt}:" <<< "${list}" | awk -F ':' '!a[$2 ":" $3]++ {print $2 ":" $3}'))
		for alti in ${!alts[@]}; do
			alti_s="${alt}:${alts[${alti}]%:*}"
			if [ ! -f "${_pa_alter_files_path}/${alti_s#*:}.alt" ]; then
				_pa_warning "alternative ${alti_s} is ghost"
				ghost_alt+=("${alti_s#*:}")
				if ${_pa_noghost}; then
					list=$(sed "/^${alti_s}:/d" <<< "${list}")
					unset alts[${alti}]
				fi
			fi
		done
		alts=(${alts[@]})
		if (("${#alts[@]}" > 1)); then
			alti_s=""
			if ${_pa_selfmode}; then
				mode=$(_pa_get_mode_by_selected_alt "${alt}" || echo "${mode}")
			fi
			if [ "${mode}" = "manual" ]; then
				_pa_info "There are ${#alts[@]} enabled alternatives in group ${_pa_blue}${alt}${_pa_bold}:"
				for alti in ${!alts[@]}; do
					_pa_message "  $((${alti}+1))) ${alts[${alti}]%%:*}\n"
				done
				_pa_message "\n"
				while ! ${_pa_noconfirm}; do
					read -p "Enter a selection (default=auto): " alti_s
					if [[ -z "${alti_s}" || "${alti_s}" = "auto" ]]; then
						alti_s=""
						break
					elif ! [[ "${alti_s}" =~ ^[0-9]+$ ]]; then
						_pa_error_message "invalid number: ${alti_s}"
					elif (("${alti_s}" < 1)) || (("${alti_s}" > "${#alts[@]}")); then
						_pa_error_message "invalid value: ${alti_s} is not between 1 and ${#alts[@]}"
					else
						alti_s=$(("${alti_s}"-1))
						break
					fi
					_pa_message "\n"
				done
			fi
			if [ -z "${alti_s}" ]; then
				for alti in ${!alts[@]}; do
					_pa_progress "$((alti+1))" "${#alts[@]}" "Auto-selecting alternatives ${alt}:* by priority"
					if [ -z "${alti_s}" ] || _pa_choose_alt_by_priority "${alt}" "${alts[${alti}]}" "${alts[${alti_s}]}"; then
						alti_s="${alti}"
					fi
				done
			fi
			for alti in $(tr ' ' '\n' <<< "${!alts[@]}" | grep -v "^${alti_s}$"); do
				list=$(sed "/^${alt}:${alts[${alti}]}/d" <<< "${list}")
			done
		elif ${_pa_noghost} && (("${#alts[@]}" == 0)); then
			_pa_init_error "all listed alternatives of group ${alt} are ghosts: ${ghost_alt[@]}"
		fi
	done
	if ${_pa_haserror}; then
		exit 1
	fi

	for alt in $(_pa_get_selected_alters -o <<< "${list}" | sort -u); do
		alt="${alt::-1}"
		if [ "${operation}" != "enable" ] || _pa_check_checksum_alter "${alt}"; then
			_pa_warning "alternative ${alt} is already selected"
			if ${_pa_needed}; then
				list=$(sed "/^${alt}:/d" <<< "${list}")
			fi
		fi
	done
	if [ -n "${ghost_alt}" ] && ! ${PA_RUN_IN_ALPM_HOOKS}; then
		ghost_alt=($(awk -F ':' '{print $1 ":" $2}' <<< "${list}" | sort -u | grep -E ":($(tr ' ' '|' <<< "${ghost_alt[@]}"))"))
		if [ -n "${ghost_alt}" ]; then
			_pa_info "Ghost alternatives are going to be selected:"
			for alt in ${ghost_alt[@]}; do
				_pa_message "  ${_pa_bold}${alt}${_pa_nostyle}\n"
			done
			_pa_question_to_continue
		fi
	fi

	echo "${list}"
}

_pa_alt_analog_by_group() {
	local alts=(${@})
	tr ' ' '\n' <<< "${_pa_enabled_alt[@]}" | \
		grep -E "^($(tr ' ' '\n' <<< "${alts[@]%:*}" | sort -u | paste -sd '|')):" | \
		grep -Ev "^($(tr ' ' '|' <<< "${alts[@]}")):" || true
}

_pa_question_to_continue() {
	local yn
	if ! ${_pa_noconfirm}; then
		_pa_message "\n"
		read -p "$(_pa_header_standard "Do you want to continue? [Y/n] ")" yn
		if ! [[ -z "${yn}" || "${yn,,}" = "y" || "${yn,,}" = "yes" ]]; then
			exit 1
		fi
	fi
}

_pa_notify_about_alt_and_get_confirm() {
	${PA_RUN_IN_ALPM_HOOKS} && return

	_pa_info "The following alternatives will be ${1}:"
	awk -F ':' -v bold="${_pa_bold}" -v nostyle="${_pa_nostyle}" '{
		if (alt != $1 ":" $2) {
			alt = $1 ":" $2
			print "  " bold alt nostyle
		}
		print "    " (($4 == "") ? "[unknown]" : $4)
	}' <<< "${2}"
	shift 1
	shift 1

	while (($#/2 > 0)); do
		if [ -n "${2}" ]; then
			_pa_message "\n"
			_pa_info "${1}:"
			_pa_message "${2}\n"
		fi
		shift 1
		shift 1
	done

	_pa_question_to_continue
}

_pa_enable() {
	_pa_selfmode=true

	local data_alt
	_pa_commit "Reading alternative files"
	data_alt=$(_pa_read_alter_file ${@})

	_pa_commit "Checking alternatives status for enabling"
	local alt alt_select=() alt_reselect=()
	if ${_pa_enable_select}; then
		alt_select+=(${data_alt})
	fi
	local alts=$(awk -F ':' '!a[$1 ":" $2]++ {print $1 ":" $2}' <<< "${data_alt}")
	for alt in ${alts}; do
		if ! ${_pa_enable_select} && ! [[ " ${alt_select[@]}" =~ " ${alt%%:*}:" ]]; then
			if [ "$(_pa_get_mode_by_selected_alt "${alt%%:*}")" = "auto" ]; then
				_pa_warning "alternative group ${alt%%:*} is on auto mode, reselecting needed"
				alt_select+=($(grep "^${alt%%:*}:" <<< "${data_alt}"))
			else
				alts=$(sed "/^${alt%%:*}:/d" <<< "${alts}")
			fi
		fi
		if [[ " ${_pa_enabled_alt[@]}" =~ " ${alt}:" ]]; then
			if _pa_check_checksum_alter "${alt}"; then
				_pa_warning "alternative ${alt} is already enabled"
				if ${_pa_needed}; then
					data_alt=$(sed "/^${alt}:/d" <<< "${data_alt}")
				fi
			elif ! ${_pa_enable_select} && [[ " ${_pa_selected_alt[@]%:*} " =~ " ${alt} " ]]; then
				_pa_warning "alternative ${alt} requires reselecting"
				alt_reselect+=($(grep "^${alt}:" <<< "${data_alt}"))
			fi
		fi
	done
	if [ -n "${alt_select}" ]; then
		_pa_commit "Checking alternatives status for selecting"
		if ${_pa_automode}; then
			for alt in $(awk -F ':' '!a[$1]++ {print $1}' <<< "${alts}"); do
				if [ "$(_pa_get_mode_by_selected_alt "${alt}")" = "manual" ]; then
					_pa_warning "alternative group ${alt} is on manual mode, selecting canceled"
					alts=$(sed "/^${alt}:/d" <<< "${alts}")
				fi
			done
			alt_select=($(tr ' ' '\n' <<< "${alt_select[@]}" | grep -E "^($(paste -sd '|' <<< ${alts})):" || true))
		fi
		if [ -n "${alts}" ]; then
			alt_select=($(_pa_needed=true _pa_select_alt ${alt_select[@]} $(_pa_alt_analog_by_group ${alts})))
		else
			alt_select=()
		fi
	fi
	alt_select+=(${alt_reselect[@]})
	if ${_pa_needed} && [[ -z "${data_alt}" && -z "${alt_select}" ]]; then
		_pa_nothing_to_do
	fi
	if [[ -n "${data_alt}" && -n "${alt_select}" ]]; then
		data_alt="$(tr ' ' '\n' <<< "${alt_select[@]}"; grep -Ev "^($(tr ' ' '|' <<< "${alt_select[@]}"))$" <<< "${data_alt}" || true)"
	fi

	if [ -n "${data_alt}" ]; then
		_pa_commit "Checking alternatives for enabling"
		_pa_check_alt "enable" ${data_alt}
	fi

	if [ -n "${alt_select}" ]; then
		_pa_commit "Checking alternatives for selecting"
		_pa_check_alt "select" ${alt_select[@]}
	fi

	if [ -n "${data_alt}" ]; then
		_pa_commit "Enabling associations"
		_pa_action_association "enable" ${data_alt}
	fi

	if [ -n "${alt_select}" ]; then
		_pa_commit "Installing associations"
		_pa_action_association "install" ${alt_select[@]}
	fi
}

_pa_disable() {
	_pa_commit "Getting enabled alternatives"
	local data_alt
	if [[ -z "${@}" ]]; then
		data_alt="$(tr ' ' '\n' <<< ${_pa_enabled_alt[@]})"
	else
		data_alt=$(_pa_get_enabled_alter ${@})
	fi

	local alt alts=($(awk -F ':' '!a[$1 ":" $2]++ {print $1 ":" $2}' <<< "${data_alt}"))
	if ${_pa_disable_ghost}; then
		_pa_commit "Searching ghost alternatives for disabling"
		for alt in ${!alts[@]}; do
			if [ -f "${_pa_alter_files_path}/${alts[alt]#*:}.alt" ]; then
				data_alt=$(sed "/^${alts[alt]}:/d" <<< "${data_alt}")
				unset alts[${alt}]
			fi
		done
		if [ -z "${data_alt}" ]; then
			_pa_nothing_to_do
		fi
	fi

	_pa_commit "Checking alternatives for disabling"
	_pa_check_alt "disable" ${data_alt}

	local reject_alt
	if ${_pa_disable_reject}; then
		reject_alt=$(_pa_select_selected_alt=true _pa_noerror=true _pa_nomessage=true _pa_get_enabled_alter ${alts[@]} || true)
		if ! (${_pa_disable_ghost} || ${_pa_automode}) && [ -z "${reject_alt}" ]; then
			_pa_warning "no alternatives found that need rejecting"
		fi
	fi
	local select_alt
	if ${_pa_automode}; then
		_pa_commit "Checking alternatives status for selecting"
		for alt in ${!alts[@]}; do
			if [ "$(_pa_get_mode_by_selected_alt ${alts[${alt}]%:*})" != "auto" ]; then
				_pa_warning "alternative group ${alts[${alt}]%:*} is on manual mode, reselecting canceled"
				unset alts[${alt}]
			fi
		done
		select_alt=$(_pa_needed=true _pa_select_alt $(_pa_alt_analog_by_group ${alts[@]}))
		if [ -n "${select_alt}" ]; then
			_pa_commit "Checking alternatives for selecting"
			_pa_check_alt "select" ${select_alt}
		fi
	fi

	_pa_notify_about_alt_and_get_confirm "disabled" "${data_alt}" \
		"The following alternatives will be rejected" \
		"$([ -n "${reject_alt}" ] && awk -F ':' '{ if (alt != $1 ":" $2) {alt = $1 ":" $2; print "  " alt}}' <<< "${reject_alt}" || true)" \
		"The following alternatives will be selected" \
		"$(awk -F ':' -v alts="$(tr ' ' ',' <<< ${alts[@]})" '{ if ($1 != "" && $2 != "") !a[$1 ":" $2]++ } END {
			split(alts, alts_array, ",")
			for (i in a) {
				split(i, i_array, ":")
				for (j in alts_array)
					if (alts_array[j] ~ i_array[1] ":")
						print "  " alts_array[j] " -> " i
			}
		}' <<< "${select_alt}")"

	if [ -n "${reject_alt}" ]; then
		_pa_commit "Removing associations"
		_pa_action_association "remove" ${reject_alt}
	fi

	_pa_commit "Disabling associations"
	_pa_action_association "disable" ${data_alt}

	if [ -n "${select_alt}" ]; then
		_pa_commit "Installing associations"
		_pa_action_association "install" ${select_alt}
	fi
}

_pa_select() {
	_pa_commit "Getting enabled alternatives"
	local data_alt
	if [[ -z "${@}" ]]; then
		data_alt="$(tr ' ' '\n' <<< ${_pa_enabled_alt[@]})"
	else
		data_alt=$(_pa_get_enabled_alter ${@})
	fi

	_pa_commit "Checking alternatives status for $(${_pa_updatemode} && echo "updating" || echo "selecting")"
	local alts=() alt_select=() alt
	if ${_pa_updatemode}; then
		alts=($(awk -F ':' '!a[$1 ":" $2]++ {print $1 ":" $2}' <<< "${data_alt}"))
		for alt in ${!alts[@]}; do
			if _pa_check_checksum_alter "${alts[${alt}]}" || \
			([ ! -f "${_pa_alter_files_path}/${alts[${alt}]##*:}.alt" ] && _pa_warning "alternative ${alts[${alt}]} is ghost, skip updating"); then
				unset alts[${alt}]
			fi
		done
	else
		alt_select=($(_pa_select_alt ${data_alt}))
	fi
	if (${_pa_updatemode} && [[ -z "${alts[@]}" ]]) || (${_pa_needed} && [ -z "${alt_select}" ]); then
		_pa_nothing_to_do
	fi
	if ${_pa_updatemode}; then
		data_alt=$(_pa_read_alter_file ${alts[@]})
		alt_select=$(_pa_get_selected_alters <<< "${data_alt}")
	fi

	if ${_pa_updatemode} && [ -n "${data_alt}" ]; then
		_pa_commit "Checking alternatives for updating"
		_pa_check_alt "enable" ${data_alt}
	fi

	if [ -n "${alt_select}" ]; then
		_pa_commit "Checking alternatives for selecting"
		_pa_check_alt "select" ${alt_select[@]}
	fi

	if ${_pa_updatemode} && [ -n "${data_alt}" ]; then
		_pa_commit "Updating associations"
		_pa_action_association "update" ${data_alt}
	fi

	if [ -n "${alt_select}" ]; then
		_pa_commit "Installing associations"
		_pa_action_association "install" ${alt_select[@]}
	fi
}

_pa_reject() {
	if ! ${_pa_automode} && ${_pa_reject_disable}; then
		_pa_selfmode=true
	fi

	_pa_commit "Getting selected alternatives"
	local data_alt
	data_alt=$(_pa_select_selected_alt=true _pa_get_enabled_alter ${@})

	_pa_commit "Checking alternatives for rejecting"
        _pa_check_alt "reject" ${data_alt}

	local alts alt_select alt
	if ${_pa_reject_replace}; then
		_pa_commit "Searching for replacements for alternatives"
		alts=$(awk -F ':' '!a[$1 ":" $2]++ {print $1 ":" $2}' <<< "${data_alt}")
		alt_select=$(_pa_select_alt $(_pa_alt_analog_by_group ${alts}))
		for alt in $(grep -Ev "^$(awk -F ':' '!a[$1]++ {print $1}' <<< "${alt_select}" | paste -sd '|'):" <<< "${alts}"); do
			_pa_warning "could not find replacement to ${alt} alternative"
		done
	fi

	_pa_notify_about_alt_and_get_confirm "rejected$(${_pa_reject_disable} && echo " and disabled" || true)" "${data_alt}" \
		"The following alternatives will be selected to replace rejected alternatives" \
		"$(awk -F ':' -v alts="$(paste -sd ',' <<< ${alts})" '{ if ($1 != "" && $2 != "") !a[$1 ":" $2]++ } END {
			split(alts, alts_array, ",")
			for (i in a) {
				split(i, i_array, ":")
				for (j in alts_array)
					if (alts_array[j] ~ i_array[1] ":")
						print "  " alts_array[j] " -> " i
			}
		}' <<< "${alt_select}")"

	_pa_commit "Removing associations"
	_pa_action_association "remove" ${data_alt}

	if ${_pa_reject_disable}; then
		_pa_commit "Disabling associations"
		_pa_action_association "disable" ${data_alt}
	fi

	if [ -n "${alt_select}" ]; then
		_pa_commit "Installing alternative associations"
		_pa_action_association "install" ${alt_select}
	fi
}

_pa_query() {
	_pa_query_print_result() {
		eval "if [ -n \"\${${1}}\" ]; then
			echo \"  ${2}:\"
			for alt in \${${1}[@]}; do
				echo \"    ${3}\"
			done
		fi"
	}

	local data_alt
	if [[ -z "${@}" ]]; then
		data_alt="$(tr ' ' '\n' <<< ${_pa_enabled_alt[@]})"
	else
		data_alt=$(_pa_nomessage=true _pa_noerror=${_pa_query_alters} _pa_get_enabled_alter ${@})
	fi

	if [ -z "${data_alt}" ]; then
		if ${_pa_guery_check}; then
			_pa_warning "there is nothing to check because there are no enabled alternatives"
			_pa_nothing_to_do
		fi
		return
	fi

	local alts alt group name
	if ${_pa_query_alters}; then
		awk -F ':' '!a[$1 ":" $2]++ {print (($1 == "") ? "[unknown]" : $1) ":" (($2 == "") ? "[unknown]" : $2)}' <<< "${data_alt}"
	elif ${_pa_query_alter_files}; then
		find ${_pa_alter_files_path} -maxdepth 1 -mindepth 1 | grep -E "/($(awk -F ':' '!a[$2]++ {if ($2 != "") print $2}' <<< "${data_alt}" | paste -sd '|')).alt$"
	elif ${_pa_query_global_list}; then
		echo "${data_alt}"
	elif ${_pa_query_list}; then
		awk -F ':' -v bold="${_pa_bold}" -v nostyle="${_pa_nostyle}" '{
			group = ($1 == "") ? "[unknown]" : $1
			name = ($2 == "") ? "[unknown]" : $2
			link_path = ($4 == "") ? "[unknown]" : $4
			print bold group ":" name nostyle " " link_path
		}' <<< "${data_alt}"
	elif ${_pa_query_info}; then
		awk -F ':' -v sysdir="${_pa_sysdir}" -v alt_files_path="${_pa_alter_files_path}/" -v bold="${_pa_bold}" -v nostyle="${_pa_nostyle}" '{
			if (alt != $1 ":" $2) {
				if (alt != "")
					print ""
				alt = $1 ":" $2
				print bold "Name" nostyle "          : " (($2 == "") ? "[unknown]" : $2)
				print bold "Group" nostyle "         : " (($1 == "") ? "[unknown]" : $1)
				print bold "Priority" nostyle "      : " (($3 == "") ? "[unknown]" : $3)
				printf bold "Ghost" nostyle "         : "
				if (system("test -f " alt_files_path $2 ".alt"))
					print "Yes"
				else
					print "No"
				printf bold "Associations" nostyle "  : "
			} else {
				printf "                "
			}
			gsub(sysdir, "", $4)
			gsub(sysdir, "", $5)
			print (($4 == "") ? "[unknown]" : $4) " -> " (($5 == "") ? "[unknown]" : $5)
		}
		END {
			print ""
		}' <<< "${data_alt}"
	elif ${_pa_guery_check}; then
		_pa_commit "Checking alternative data integrity"
		data_alt=(${data_alt})
		for alt in $(_pa_nomessage=true _pa_check_alter_data_integrity ${_pa_enabled_alt[@]}); do
			_pa_error_message "alternative data has an integrity problem: ${_pa_enabled_alt[${alt}]}"
			_pa_non_integrity_alt+=("${_pa_enabled_alt[${alt}]}")
			data_alt=($(sed "s| ${_pa_enabled_alt[${alt}]} | |" <<< " ${data_alt[@]} "))
		done
		if [[ "${#data_alt[@]}" = "0" ]]; then
			_pa_error "all alternative data have integrity problems"
		fi

		_pa_commit "Comparing alternative data with data from alternative files"
		alts=($(awk -F ':' -v RS=' ' '!a[$1 ":" $2]++ {print $1 ":" $2}' <<< "${data_alt[@]}"))
		local data_file fail_checksum fail_diff issue_data=()
		for alt in ${alts[@]}; do
			if [ -f "${_pa_alter_files_path}/${alt#*:}.alt" ]; then
				data_file=$(_pa_nomessage=true _pa_noerror=true _pa_read_alter_file "${alt}")
				if [ -z "${data_file}" ]; then
					_pa_error_message "failed to read alternative file ${alt} correctly: alternative file is corrupted"
					issue_data+=("${alt}")
				else
					fail_checksum=false
					fail_diff=false
					if ! _pa_check_checksum_alter "${alt}"; then
						_pa_warning "alternative sum check ${alt} failed"
						fail_checksum=true
					fi
					if ! diff <(tr ' ' '\n' <<< "${data_alt[@]}" | grep "^${alt}:" | sort) <(sort <<< "${data_file}") > /dev/null 2>&1; then
						_pa_warning "there are differences in data with alternative file ${alt}"
						fail_diff=true
					fi
					if ! ${fail_checksum} && ${fail_diff}; then
						_pa_error_message "alternative data ${alt} has changes that are not committed by checksum"
						issue_data+=("${alt}")
					fi
				fi
			else
				_pa_error_message "alternative ${alt} is ghost: alternative file not found"
				issue_data+=("${alt}")
			fi
		done

		_pa_commit "Checking for alternative associations"
		local issue_env=($(_pa_check_alt "query" ${data_alt[@]}))

		_pa_commit "Checking selected alternatives"
		local issue_select=($(_pa_selfmode=true _pa_action_association "query" $(tr ' ' '\n' <<< ${data_alt[@]} | _pa_get_selected_alters) | sort -u))

		_pa_info "Check result:"
		if [[ -z "${_pa_non_integrity_alt}" && -z "${issue_data}" && -z "${issue_env}" && -z "${issue_select}" ]]; then
			_pa_nothing_to_do
		fi
		_pa_query_print_result "_pa_non_integrity_alt" "found alternative data that have integrity problems, such data skips checking" '${alt}'
		_pa_query_print_result "issue_data" "found problems with verification of alternative data" '${alt}'
		_pa_query_print_result "issue_env" "found alternatives that have environmental problems" '${data_alt[${alt}]}'
		_pa_query_print_result "issue_select" "found alternatives that have problems with selected associations" '${alt}'
	else
		alts=($(awk -F ':' '!a[$1 ":" $2]++ {print $1 ":" $2 ":" $3}' <<< "${data_alt}"))
		for alt in $(tr ' ' '\n' <<< ${alts[@]%%:*} | sort -u); do
			echo -e "${_pa_bold}${alt}${_pa_nostyle}"
			if ! ${_pa_query_groups}; then
				for name in $(awk -F ':' -v RS=' ' -v alt="${alt}" '{if (alt == $1) print (($2 == "") ? "[unknown]" : $2) ":" $3}' <<< "${alts[@]}"); do
					echo -n "  ${name:=[unknown]}"
					if [[ " ${_pa_selected_alt[@]%:*} " =~ " ${alt}:${name%%:*} " ]]; then
						echo -n " [selected:$(_pa_get_mode_by_selected_alt ${alt})]"
					fi
					echo
				done
			fi
		done
	fi
}

_pa_install() {
	local file_alt=(${@})

	_pa_commit "Checking alternatives status for installing"
	local alt altf altf altf_modified=()
	for alt in ${!file_alt[@]}; do
		altf="${_pa_alter_files_path}/${file_alt[${alt}]##*/}"
		if [ -f "${altf}" ]; then
			if [[ "$(_pa_get_checksum_alter "${file_alt[${alt}]}")" = "$(_pa_get_checksum_alter "${altf}")" ]]; then
				_pa_warning "alternative file ${file_alt[${alt}]##*/} is already installed"
				if ${_pa_needed}; then
					unset file_alt[${alt}]
				fi
			else
				altf_modified+=("${file_alt[${alt}]##*/}")
			fi
		fi
	done
	if [[ -z "${file_alt[@]}" ]]; then
		_pa_nothing_to_do
	fi

	local data_alt
	_pa_commit "Reading alternative files"
	data_alt=$(_pa_read_alter_file ${@})

	_pa_commit "Checking alternative for installing"
	_pa_check_alt "install" ${data_alt}

	if [ -n "${altf_modified}" ]; then
		_pa_notify_about_alt_and_get_confirm "installed with modified associations" \
			"$(grep -E ":($(tr ' ' '|' <<< ${altf_modified[@]%.*})):" <<< "${data_alt}")"
	fi

	_pa_commit "Installing alternatives"
	for alt in ${!file_alt[@]}; do
		_pa_progress_noret=true _pa_progress "$((alt+1))" "${#file_alt[@]}" "installing ${file_alt[${alt}]##*/} file alternative"
		cp -r ${file_alt[${alt}]} ${_pa_alter_files_path}
	done
}

_pa_uninstall() {
	local file_alt=() alt altf
	for alt in ${@#*:}; do
		altf="${_pa_alter_files_path}/${alt}.alt"
		if [ ! -f "${altf}" ]; then
			_pa_init_error "alternative file ${alt}.alt not found"
		else
			file_alt+=("${altf}")
		fi
	done
	if ${_pa_haserror}; then
		exit 1
	fi

	local data_alt
	_pa_commit "Reading alternative files"
	data_alt=$(_pa_read_alter_file ${@})

	_pa_commit "Checking alternative for uninstalling"
	_pa_check_alt "uninstall" ${data_alt}

	_pa_notify_about_alt_and_get_confirm "uninstalled" "${data_alt}"

	_pa_commit "Uninstalling alternatives"
	for alt in ${!file_alt[@]}; do
		_pa_progress_noret=true _pa_progress "$((alt+1))" "${#file_alt[@]}" "removing ${file_alt[${alt}]##*/} file alternative"
		rm ${file_alt[${alt}]}
	done
}

_pa_help_main() {
	_pa_message "usage:  pacman-alternatives <operation> [...]
operations:
    pacman-alternatives {-h --help}
    pacman-alternatives {-V --version}
    pacman-alternatives {-E --enable}     [options] [alternative(s)]
    pacman-alternatives {-D --disable}    [options] [alternative(s)]
    pacman-alternatives {-S --select}     [options] [alternative(s)]
    pacman-alternatives {-R --reject}     [options] [alternative(s)]
    pacman-alternatives {-Q --query}      [options] [alternative(s)]
    pacman-alternatives {-I --install}    [options] [file(s)]
    pacman-alternatives {-U --uninstall}  [options] [alternatives(s)]

use 'pacman-alternatives <operation> {-h --help}' with an operation for available options\n"
}

_pa_help_enable() {
	_pa_message "usage:  pacman-alternatives {-E --enable} [options] [alternative(s)]
options:
  -a, --auto
  -s, --select
      --needed
      --noconfirm
      --noghost
      --overwrite\n"
}

_pa_help_disable() {
	_pa_message "usage:  pacman-alternatives {-D --disable} [options] [alternative(s)]
options:
  -a, --auto
  -g, --ghost
  -r, --reject
      --noconfirm\n"
}

_pa_help_select() {
	_pa_message "usage:  pacman-alternatives {-S --select} [options] [alternative(s)]
options:
  -a, --auto
  -u, --update
      --needed
      --noconfirm
      --noghost
      --overwrite\n"
}

_pa_help_reject() {
	_pa_message "usage:  pacman-alternatives {-U --reject} [options] [alternative(s)]
options:
  -a, --auto
  -d, --disable
  -r, --replace
      --noconfirm
      --noghost\n"
}

_pa_help_query() {
	_pa_message "usage:  pacman-alternatives {-Q --query} [options] [alternative(s)]
options:
  -a, --alternatives
  -c, --check
  -f, --alterfiles
  -g, --groups
  -i, --info
  -l, --list (-ll)\n"
}

_pa_help_install() {
	_pa_message "usage:  pacman-alternatives {-I --install} [options] [alternative(s)]
options:
  --needed
  --noconfirm\n"
}

_pa_help_uninstall() {
	_pa_message "usage:  pacman-alternatives {-U --uninstall} [options] [alternative(s)]
options:
  --noconfirm\n"
}

_pa_version_info() {
	_pa_message "version: ${_pa_version}\n"
}

_pa_run_operation() {
	_pa_run_operation_add_alter() {
		if ! [[ " ${alters[@]} " =~ " ${1} " ]]; then
			alters+=("${1}")
		fi
	}

	local operation="${1}" arg_alters=()
	shift 1

	case "${operation}" in
		"enable"|"disable"|"select"|"reject"|"query"|"install"|"uninstall");;
		*) _pa_error "internal error: unknown operation '${operation}' for _pa_run_operation";;
	esac

	eval "$(awk -F ':' -v ps_args="$(tr ' ' ',' <<< ${_pa_args[@]})" -v RS=" " 'BEGIN {
		split(ps_args, args_array, ",")
	}
	{
		len=0
		for (i in args_array)
			if (args_array[i] == $1)
				len++
		if (len >= $2) {
			split($3, funcs, ",")
			for (i in funcs) {
				gsub(/\n/, "", funcs[i])
				print "_pa_" funcs[i] "=true"
			}
			for (i in args_array)
				if (args_array[i] == $1)
					delete args_array[i]
		}
	}
	function print_array(name, array) {
		printf name "=("
		for (i in array)
			printf array[i] " "
		print ")"
	}
	END {
		i=1
		for (j in args_array) {
			arg = args_array[j]
			if (substr(arg, 1, 1) == "-")
				args[i] = arg
			else
				alts[i] = arg
			i++
		}
		print_array("_pa_args", args)
		print_array("arg_alters", alts)
	}' <<< "${@}")"

	if [ -n "${_pa_args}" ]; then
		_pa_error "invalid option '$(tr ' ' '\n' <<< "${_pa_args[@]}" | sort -u | paste -sd ' ')'"
	fi

	if ${_pa_helpmode}; then
		_pa_help_${operation}
		return
	fi

	eval "$(awk -v RS=' ' 'BEGIN {
		i=1
	}
	{
		gsub(/\n/, "", $1)
		syn[i] = $1
		i++
	}
	END {
		len = i-1
		for (i in syn) {
			for (j in syn) {
				if (i == j)
					continue
				x=(i+len**(i%2+1))*(j+len**(j%2+1))
				if (!(x in sort))
					sort[x] = syn[i] ":" syn[j]
			}
		}
		for (i in sort) {
			split(sort[i], sort_array, ":")
			print "${_pa_" sort_array[1] "} && ${_pa_" sort_array[3] "} && _pa_error \"invalid option: '"'"'--" sort_array[2] "'"'"' and '"'"'--" sort_array[4] "'"'"' may not be used together\" || true"
		}
	}' <<< "${_pa_conflicting_args}")"

	_pa_read_enabled_alters

	local alters=() alter group name
	for alter in ${arg_alters[@]}; do
		if ${_pa_arg_is_altfile}; then
			if [[ "${alter::1}" != "/" && "${alter::1}" != "." ]]; then
				alter="./${alter}"
			fi
			alter="$(realpath ${alter})"
			if [ -f "${alter}" ]; then
				if [ "${alter##*.}" != "alt" ]; then
					_pa_init_error "specified file is not alternative file"
				else
					_pa_run_operation_add_alter "${alter}"
				fi
				continue
			fi
		else
			if ! [[ "${alter}" =~ ":" ]]; then
				alter=$(${_pa_only_group} && echo "${alter}:" || echo ":${alter}")
			fi
			group="${alter%%:*}"
			name="${alter##*:}"
			: "${group:="*"}"
			: "${name:="*"}"
			if [[ "${group}" = "*" && "${name}" = "*" ]]; then
				_pa_error "syntax error: alternative unassigned"
			fi
			alter="${group}:${name}"
			if grep -Eqs "(^| )alter_group_${group//\*/\.*}( |\()" "${_pa_alter_files_path}/"${name}".alt" || \
				grep -q " ${alter//\*/\.*}:" <<< " ${_pa_enabled_alt[@]}"; then
				if (${_pa_only_group} && [ "${name}" != "*" ]) || (${_pa_only_name} && [ "${group}" != "*" ]); then
					_pa_warning "alternative ${alter} will be ignored (need to specify $(${_pa_only_group} && echo "group" || echo "name"))"
				else
					_pa_run_operation_add_alter "${alter}"
				fi
				continue
			fi
		fi
		_pa_init_error "alternative not found: ${alter}"
	done
	if ${_pa_haserror}; then
		exit 1
	fi

	if ! ${_pa_norequire_alt} && ((${#alters} == 0)); then
		_pa_error "no targets specified"
	fi

	_pa_read_selected_alters
	_pa_static_selected_alt=(${_pa_selected_alt[@]})

	trap '_pa_chmod_alters -w' EXIT
	_pa_chmod_alters +w
	_pa_${operation} "${alters[@]}"
}

_pa_title_error="error:"
_pa_title_warning="warning:"
if ${PA_RUN_IN_ALPM_HOOKS}; then
	_pa_title_error="==> ERROR:"
	_pa_title_warning="==> WARNING:"
fi

if [ "$(type -t pacman-conf)" != "file" ]; then
	_pa_error "pacman-conf not found"
fi

_pa_pacman_dbpath="$(pacman-conf DBPath)"
if [ -z "${_pa_pacman_dbpath}" ]; then
	_pa_error "failed to define DBPath in pacman-conf"
fi

_pa_style="$(pacman-conf Color)"
if [ -z "${_pa_style}" ]; then
	_pa_style=false
else
	_pa_style=true
fi
if ${_pa_style}; then
	_pa_bold="\033[0;1m"
	_pa_nostyle="\033[0m"
	_pa_blue="\033[1;34m"
	_pa_green="\033[1;32m"
	_pa_yellow="\033[1;33m"
	_pa_red="\033[1;31m"
fi

_pa_title_header="${_pa_blue}::"
_pa_title_progress=""
if ${PA_RUN_IN_ALPM_HOOKS}; then
	_pa_title_header="${_pa_green}==>"
	_pa_title_progress="  ${_pa_blue}->${_pa_bold} "
fi

if ! _pa_check_dir_path "${_pa_sysdir}"; then
	_pa_init_error "sysdir path value is invalid: ${_pa_sysdir}"
fi
if [ ! -d "${_pa_alter_files_path}" ]; then
	_pa_init_error "path to alternative files not found: ${_pa_alter_files_path}"
fi
if [ ! -d "${_pa_enabled_alters_path}" ]; then
	_pa_init_error "path to alternatives not found: ${_pa_enabled_alters_path}"
fi
if ${_pa_haserror}; then
	exit 1
fi

_pa_args=($(awk -v RS=' ' '{
	gsub(/\x1B\[[0-9;]*[A-Za-z]/, "", $1)
	if (substr($1, 1, 1) == "-") {
		count = gsub("-", "", $1)
		if (count == 1)
			gsub(/./, " -&", $1)
		else if (count >= 2)
			printf "--"
	}
	print $1
}' <<< "${@}"))
_pa_conflicting_args=""

_pa_root_arg="${_pa_args[0]}"
unset _pa_args[0]

if [ -z "${_pa_root_arg}" ]; then
	_pa_error "no operation specified (use -h for help)"
fi

case "${_pa_root_arg}" in
	-E|--enable)
	_pa_run_operation enable \
		-{s,-select}:1:enable_select \
		-{a,-auto}:1:automode,enable_select \
		-{h,-help}:1:helpmode \
		--needed:1:needed \
		--noconfirm:1:noconfirm \
		--noghost:1:noghost \
		--overwrite:1:overwrite
	;;
	-D|--disable)
	_pa_conflicting_args="disable_ghost:ghost automode:auto"
	_pa_run_operation disable \
		-{a,-auto}:1:automode,disable_reject \
		-{g,-ghost}:1:disable_ghost,disable_reject,norequire_alt \
		-{u,-reject}:1:disable_reject \
		-{h,-help}:1:helpmode \
		--noconfirm:1:noconfirm
	;;
	-S|--select)
	_pa_conflicting_args="automode:auto updatemode:update"
	_pa_run_operation select \
		-{a,-auto}:1:automode,onlygroup \
		-{u,-update}:1:updatemode,norequire_alt \
		-{h,-help}:1:helpmode \
		--needed:1:needed \
		--noconfirm:1:noconfirm \
		--noghost:1:noghost \
		--overwrite:1:overwrite
	;;
	-R|--reject)
	_pa_run_operation reject \
		-{r,-replace}:1:reject_replace \
		-{d,-disable}:1:reject_disable \
		-{a,-auto}:1:automode,reject_replace,reject_disable \
		-{h,-help}:1:helpmode \
		--noconfirm:1:noconfirm \
		--noghost:1:noghost
	;;
	-Q|--query)
	_pa_norequire_alt=true
	_pa_conflicting_args="guery_check:check query_groups:groups query_info:info query_list:list query_alters:alternatives query_alter_files:alterfiles"
	_pa_run_operation query \
		-{h,-help}:1:helpmode \
		-{c,-check}:1:guery_check \
		-{g,-groups}:1:query_groups \
		-{i,-info}:1:query_info \
		-{l,-list}:2:query_list,query_global_list \
		-{l,-list}:1:query_list \
		-{a,-alternatives}:1:query_alters \
		-{f,-alterfiles}:1:query_alter_files
	;;
	-I|--install)
	_pa_arg_is_altfile=true
	_pa_run_operation install \
		-{h,-help}:1:helpmode \
		--needed:1:needed \
		--noconfirm:1:noconfirm
	;;
	-U|--uninstall)
	_pa_only_name=true
	_pa_run_operation uninstall \
		-{h,-help}:1:helpmode \
		--noconfirm:1:noconfirm
	;;
	-V|--version)
	_pa_version_info
	;;
	-h|--help)
	_pa_help_main
	;;
	*)
	_pa_error "invalid option ${_pa_root_arg}"
	;;
esac

exit 0

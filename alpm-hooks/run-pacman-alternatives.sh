#!@BASHPATH@

set -e

alts=()
export PA_RUN_IN_ALPM_HOOKS=true

while read -r i; do
	alt="$(basename "${i//.alt/}")"
	if [[ -n "${alt}" && "${alt}" != "*" ]]; then
		alts+=("${alt}")
	fi
done

if [[ -n "${alts}" && ("${1}" = "update" || "${1}" = "disable") ]]; then
	alts=($(pacman-alternatives -Qa ${alts[@]}))
fi

if [ -z "${alts}" ]; then
	exit 0
fi

pacman-alternatives $(case "${1}" in
	"enable")  echo "-Ea";;
	"update")  echo "-Su";;
	"disable") echo "-Da";;
	esac) ${alts[@]} --overwrite

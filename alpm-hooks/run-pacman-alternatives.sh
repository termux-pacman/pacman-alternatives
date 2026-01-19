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

case "${1}" in
	"enable") pacman-alternatives -Ea ${alts[@]} --overwrite;;
	"update") pacman-alternatives -Su ${alts[@]};;
	"disable") pacman-alternatives -Da ${alts[@]};;
esac

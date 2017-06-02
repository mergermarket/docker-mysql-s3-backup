# based on https://github.com/concourse/git-resource/blob/master/test/helpers.sh#L19
_run() {
	export TEMPDIR=$(mktemp -d ${TEMPDIR_ROOT}/tests.XXXXXX)

	echo -e 'running \e[33m'"$@"$'\e[0m...'

	eval "set -e -u -o pipefail; _before_each && $@ && _after_each" 2>&1 | sed -e 's/^/  /g'
	echo ""
}



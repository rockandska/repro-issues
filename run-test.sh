#!/usr/bin/env bash
set -euo pipefail

PREFIX="test-tmux"
DOCKER_IMAGES=("ubuntu:18.04" "ubuntu:20.04" "ubuntu:22.04")
TMUX_VERSIONS=("3.2" "3.2a" "3.3" "3.3a" "master")

[[ -z "${DEBUG:-}" ]] && QUIET="-q"

for i in "${DOCKER_IMAGES[@]}";do
	echo ""
	echo "$i in use"
	cname="${PREFIX}-${i//[^[:alnum:]]/_}"
	imgname="${PREFIX}:${i//[^[:alnum:]]/_}"
	cache_dir="${PWD}/tmp/cache/${cname}"
	mkdir -p "${cache_dir}"
	echo "Building docker image : $imgname"
	docker build \
		${QUIET:-} \
		-t "${imgname}" \
		--build-arg UID="$(id -u)" \
		--build-arg GID="$(id -g)" \
		--build-arg image="$i" \
		-f Dockerfile .

	docker rm -f "${cname}" &> /dev/null || true

	echo "Starting container $cname"
	docker run \
		--name "${cname}" \
		--volume "${cache_dir}:/home/test" \
		-d \
		"${imgname}" \
		bash -l -c "tail -f /dev/null"

	for v in "${TMUX_VERSIONS[@]}";do
		echo ""
		echo "Starting test with version $v"
		docker exec \
			-i \
			-e v="$v" \
			-e DEBUG="${DEBUG:-}"  \
			"$cname" \
			bash /tmp/test-script.sh &> $cache_dir/log-$v && rc="$?" || rc="$?"

		if [[ "${rc}" -eq 0 ]];then
			echo "$v and $imgname -> OK (status: $rc)"
		else
			echo "$v and $imgname -> ERR (status: $rc)"
		fi
		echo "Log: $cache_dir/log-$v"
	done
done

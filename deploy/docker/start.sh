#!/bin/busybox sh
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Run the standard AX installer against this container's private Docker daemon.
set -eu

run_stack() {
  until docker info >/dev/null 2>&1; do sleep 1; done
  # Only the outer Compose network and loopback may reach the AX API.
  # Packets from Kind enter on an inner Docker bridge in this namespace.
  iptables -I INPUT ! -i eth0 -p tcp --dport 8080 -j DROP
  iptables -I INPUT -i lo -p tcp --dport 8080 -j ACCEPT
  if docker container inspect kind-registry >/dev/null 2>&1; then
    docker start kind-registry
  else
    docker run -d --restart=unless-stopped --name kind-registry \
      -p 127.0.0.1:5001:5000 registry:3
  fi

  cd /opt/ax
  for image in server task-runner; do
    tag="localhost:5001/ax-${image}:local"
    # A new provenance timestamp would roll ax-server on every stack restart.
    docker build --provenance=false -t "$tag" -f "Dockerfile.${image}" .
    docker push "$tag"
  done
  ax local start --local-registry \
    --server-image localhost:5001/ax-server:local \
    --default-task-image localhost:5001/ax-task-runner:local

  # kubectl exits when the selected pod is replaced. Reconnect to the service.
  while true; do
    kubectl --context ax-local -n ax-system port-forward --address=0.0.0.0 \
      service/ax-server 8080:8080 || true
    sleep 2
  done
}

if [ "${1:-}" = 'run-stack' ]; then
  run_stack
  exit
fi

# The entrypoint normally enables TCP when its first argument is a flag.
# Supply dockerd explicitly so only the private Unix socket is created.
dockerd-entrypoint.sh dockerd --host="$DOCKER_HOST" &
daemon_pid=$!
# A separate process group lets a stop interrupt an image build or installation.
setsid "$0" run-stack &
stack_pid=$!

shutdown() {
  kill -TERM "-$stack_pid" 2>/dev/null || true
  wait "$stack_pid" 2>/dev/null || true
  kill -TERM "$daemon_pid" 2>/dev/null || true
  wait "$daemon_pid" 2>/dev/null || true
}
trap 'shutdown; exit 0' INT TERM
# An unexpected exit of either component makes the stack unhealthy.
# BusyBox ash in docker:dind implements wait -n.
# shellcheck disable=SC3045
wait -n || true
shutdown
exit 1

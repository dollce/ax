#!/usr/bin/env bash
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

# Exercise the same stack file that Portainer accepts on a local Docker engine.
set -euo pipefail
cd "$(dirname "$0")/.."
COMPOSE_PROJECT_NAME="ax-smoke-$(date +%s)-$$"
export COMPOSE_PROJECT_NAME
export AX_STACK_IMAGE="ax-local:${COMPOSE_PROJECT_NAME}"
export AX_PORT=0

cleanup() {
  if [[ $? != 0 ]]; then
    docker compose logs --tail 100 ax >&2
  fi
  docker compose down --volumes
  docker image rm "${AX_STACK_IMAGE}"
}
docker build -f deploy/docker/Dockerfile -t "${AX_STACK_IMAGE}" .
trap cleanup EXIT

docker compose up -d --wait --wait-timeout 1200
curl -fsS "http://$(docker compose port ax 8080)/healthz"
docker compose exec -T ax ax apply -f /opt/ax/hello.yaml
docker compose exec -T ax ax resume task hello

for _ in {1..60}; do
  description=$(docker compose exec -T ax ax describe task hello)
  if grep -Fq 'TASK_RESULT_SUCCEEDED (exitCode=0)' <<< "${description}"; then
    break
  fi
  sleep 1
done
grep -Fq 'TASK_RESULT_SUCCEEDED (exitCode=0)' <<< "${description}"
grep -Fxq '  hello from AX' <<< "${description}"

# Recreate the outer container so the task must be recovered from its volumes.
docker compose down
docker compose up -d --wait --wait-timeout 1200
docker compose exec -T ax ax describe task hello | grep -Fx '  hello from AX'

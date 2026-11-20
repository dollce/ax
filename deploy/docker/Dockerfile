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

FROM --platform=$BUILDPLATFORM golang:1.27.1 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
ARG TARGETARCH
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -trimpath \
      -o /out/ ./cmd/ax ./cmd/ax-server ./cmd/ax-task-runner

FROM docker:29-dind
ARG TARGETARCH
ENV PATH="/root/.ax/bin:${PATH}" DOCKER_HOST=unix:///var/run/docker.sock
COPY --from=build /out/ax /usr/local/bin/
COPY --from=build /out/ax-server /out/ax-task-runner /opt/ax/bin/linux_${TARGETARCH}/
COPY Dockerfile.server Dockerfile.task-runner deploy/docker/hello.yaml /opt/ax/
COPY --chmod=755 deploy/docker/start.sh /usr/local/bin/start-ax
ENTRYPOINT ["docker-init", "--", "/usr/local/bin/start-ax"]
CMD []

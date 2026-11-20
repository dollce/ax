# Run AX with Docker and Portainer

The stack runs the AX CLI, a private Docker engine and a Kind cluster in one
container. Inside it, Agent Substrate runs the task sandboxes and PostgreSQL
stores AX resources. The host needs a rootful Linux Docker engine that permits
privileged containers, a Linux kernel of at least 6.8, and at least 4 GiB of
memory available to the engine (6 GiB or more recommended). On Docker Desktop
these requirements apply to its Linux VM.

## Build the stack image

Run this from the repository root on the Docker endpoint that will run AX.

```sh
docker build -f deploy/docker/Dockerfile -t ax-local:dev .
```

The first start downloads Kind and kubectl, builds the AX server and runner
images, and pulls the Kind node, PostgreSQL and Substrate images. It can take
several minutes. The installer uses `ax local start --local-registry` to make
the private `localhost:5001` registry available to Kind and Substrate. Its
contents stay on this endpoint.

## Start with Docker Compose

```sh
docker compose up -d
docker compose logs -f ax
```

Once `docker compose ps` reports `healthy`, run `curl -fsS http://127.0.0.1:8080/healthz`.
The AX API accepts unauthenticated requests. The stack publishes it on host
loopback. To choose a different port, set `AX_PORT` before running Compose.

## Start with Portainer

1. Open the **Docker Standalone** environment that has the stack image.
2. Select **Stacks → Add stack**, enter a name, choose **Upload**, and select
   the repository's `compose.yaml`. You can also paste it into **Web editor**.
3. For a remote endpoint, build the image there or publish it to your own
   registry and set `AX_STACK_IMAGE` to the accessible tag or digest under
   **Environment variables**. Set `AX_PORT` if the endpoint already uses 8080.
4. Select **Deploy the stack**. Open the `ax` container's logs for installation
   progress. When healthy, open its **Console** using `/bin/sh` and run
   `ax get tasks`. The published port belongs to the Docker endpoint.

## Run a task

From the repository root, submit the example and start it.

```sh
docker compose exec -T ax ax apply -f - < deploy/docker/hello.yaml
docker compose exec -T ax ax resume task hello
docker compose exec -T ax ax describe task hello
```

In the Portainer container console, run `ax apply -f /opt/ax/hello.yaml`,
`ax resume task hello` and `ax describe task hello`.

Once complete, the description includes `exitCode=0` and the output
`hello from AX`. To submit manifests from a host CLI, use
`ax --server http://127.0.0.1:8080 apply -f task.yaml`. For `ax ssh` on a
task with `spec.debug: true`, run the CLI inside the stack container so it
can use the cluster's kubeconfig and Substrate router.

To test a checkout end to end, run `./hack/test-docker-stack.sh`. It builds
the image, submits this example to a fresh Compose project, verifies the
result again after recreating the container, and removes its test volumes.

## Stop and resume

Suspend any running tasks whose workspace you want to checkpoint. Use
`docker compose down` to remove the container or **Stop this stack** in
Portainer. Start again with `docker compose up -d` or **Start this stack**.
Use the same project or stack name to reattach the named volumes containing
the nested engine, AX tools and kubeconfig. Allow a few minutes for the
cluster services to become healthy again. To permanently erase the local
cluster and its tasks, use `docker compose down -v` or remove the stack and
its named volumes in Portainer.

SHELL := /bin/bash

.PHONY: fmt validate app-smoke docker-build export-task-def-dev export-task-def-test

fmt:
	terraform fmt -recursive

validate:
	terraform -chdir=infra/environments/dev init -backend=false
	terraform -chdir=infra/environments/dev validate
	terraform -chdir=infra/environments/test init -backend=false
	terraform -chdir=infra/environments/test validate

app-smoke:
	python3 app/server.py & \
	server_pid=$$!; \
	trap 'kill "$$server_pid"' EXIT; \
	sleep 2; \
	curl --fail http://127.0.0.1:8080/health

docker-build:
	docker build -t ecs-terraform-example-local ./app

export-task-def-dev:
	./scripts/export-task-def.sh dev hello-ecs

export-task-def-test:
	./scripts/export-task-def.sh test hello-ecs

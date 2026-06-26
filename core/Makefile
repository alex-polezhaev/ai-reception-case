create-network:
	docker network create ai-reception-net

build-workers-image-prod:
	DOCKER_BUILDKIT=1 docker build --build-arg SWIFT_BUILD_CONFIG=release -t ai-reception/workers:0.1 ./workers

build-workers-prod:
	docker compose --env-file .env \
	 -f workers/docker-compose.yml up --build -d

build-silero-vad-prod:
	docker compose --env-file .env \
	 -f silero-vad/docker-compose.yml up --build -d

build-silero-vad-dev:
	docker compose --env-file .env.dev \
	 -f silero-vad/docker-compose.yml up --build -d

build-nginx-prod:
	docker compose --env-file .env \
	 -f nginx/docker-compose.yml up --build -d

build-portainer-prod:
	docker compose --env-file .env \
	 -f portainer/docker-compose.yml up --build -d

build-dozzle-prod:
	docker compose --env-file .env \
	 -f dozzle/docker-compose.yml up --build -d

docker-build-prod:
	make build-workers-prod
	make build-silero-vad-prod
	make build-nginx-prod
	make build-portainer-prod
	make build-dozzle-prod
	docker restart ai-reception-nginx


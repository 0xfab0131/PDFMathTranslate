.PHONY: next pull down logs

next:
	docker compose up --build

pull:
	docker compose pull

down:
	docker compose down

logs:
	docker compose logs -f
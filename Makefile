.PHONY: next-openai next-ollama down logs

next-openai:
	docker compose up

next-ollama:
	docker compose -f docker-compose.yml -f docker-compose.ollama.yml up

down:
	docker compose down

logs:
	docker compose logs -f
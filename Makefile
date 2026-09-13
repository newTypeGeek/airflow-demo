.DEFAULT_GOAL := help

.PHONY: help git-init init up down reset logs test lint version-info

help:
	@printf '%s\n' \
	  'make git-init      Initialize this directory as a main-branch Git repository.' \
	  'make init          Build the image and initialize Airflow metadata in Postgres.' \
	  'make up            Start Airflow services.' \
	  'make down          Stop Airflow services.' \
	  'make reset         Remove Airflow containers and database volume.' \
	  'make logs          Follow Airflow DAG processor logs.' \
	  'make lint          Run Ruff using uv.' \
	  'make test          Run DAG tests using uv.' \
	  'make version-info  Show each versioned_demo run and its Git bundle version.'

git-init:
	@test -d .git || git init -b main
	@git add dags/versioned_demo.py
	@git diff --cached --quiet || git commit -m "Add versioned demo DAG v1"

init:
	@mkdir -p logs
	docker compose build
	docker compose up airflow-init

up:
	docker compose up -d

down:
	docker compose down

reset:
	docker compose down --volumes --remove-orphans

logs:
	docker compose logs --follow airflow-dag-processor

lint:
	uv run ruff check .

test:
	uv run pytest

version-info:
	docker compose exec postgres psql -U airflow -d airflow -c "SELECT dr.run_id, dr.logical_date, dv.bundle_name, dv.bundle_version FROM dag_run AS dr JOIN dag_version AS dv ON dv.id = dr.dag_version_id WHERE dr.dag_id = 'versioned_demo' ORDER BY dr.logical_date;"

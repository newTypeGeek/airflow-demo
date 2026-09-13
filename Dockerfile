FROM apache/airflow:3.3.1

COPY --from=ghcr.io/astral-sh/uv:0.9.18 /uv /uvx /bin/

COPY --chown=airflow:root pyproject.toml uv.lock /opt/airflow/project/
WORKDIR /opt/airflow/project
RUN uv export --frozen --no-dev --no-emit-project --no-hashes --output-file /tmp/requirements.txt \
	&& uv pip install --system --no-cache --no-deps -r /tmp/requirements.txt \
	&& rm /tmp/requirements.txt

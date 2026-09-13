# Airflow 3 DAG Versioning Demo

This project demonstrates reproducible DAG runs with Apache Airflow 3.3.1. Airflow
loads the DAG from this local directory through `GitDagBundle`; each DAG run stores
the Git commit of the bundle it used. A rerun can therefore use the original DAG code
after a newer commit has been deployed.

PostgreSQL 16 is the Airflow metadata database. Redis is intentionally not used: this
small demo uses `LocalExecutor`, which keeps the Compose stack smaller while retaining
the Airflow 3 API server, scheduler, DAG processor, and triggerer services.

## GitDagBundle Configuration

The DAG processor must receive `AIRFLOW__DAG_PROCESSOR__DAG_BUNDLE_CONFIG_LIST` when
the Airflow containers start. It is a JSON list of DAG bundle definitions; this project
sets it for every Airflow service in `docker-compose.yaml`:

```yaml
AIRFLOW__DAG_PROCESSOR__DAG_BUNDLE_CONFIG_LIST: >-
    [{"name":"local-git-dags","classpath":"airflow.providers.git.bundles.git.GitDagBundle","kwargs":{"repo_url":"file:///opt/airflow/project","tracking_ref":"main","subdir":"dags","refresh_interval":5}}]
```

The `apache-airflow-providers-git` package must also be installed in the Airflow image;
it provides the `GitDagBundle` class. The bundle configuration means:

- `name`: the bundle name saved with DAG versions and shown as `local-git-dags`.
- `classpath`: the provider class Airflow instantiates to retrieve the bundle.
- `repo_url`: the Git repository URL visible inside the container. This demo mounts the
    project read-only at `/opt/airflow/project`, so it uses a local `file://` URL.
- `tracking_ref`: the branch, tag, or commit Airflow fetches. `main` makes new runs use
    the newest commit on that branch.
- `subdir`: the repository directory that contains DAG files.
- `refresh_interval`: seconds between checks for an updated bundle; it does not replace
    the DAG processor's separate parsing cycle.

For a remote private repository, use `git_conn_id` in `kwargs` instead of embedding
credentials in `repo_url`. Store the connection credentials in an Airflow connection or
secrets backend, since bundle configuration can be exposed through Airflow's Config API.

## Prerequisites

- Docker Desktop for macOS with at least 4 GB of memory allocated (8 GB recommended)
- Docker Compose v2 or newer
- Git
- [uv](https://docs.astral.sh/uv/)

The Compose environment is for local learning and development, not production use.

## Bootstrap

```sh
cp .env.example .env
uv sync
make git-init
make init
make up
```

`make git-init` creates a `main` branch and commits the v1 DAG if the workspace is not
already a Git repository. `GitDagBundle` reads committed Git content, so commit each DAG
change before expecting Airflow to load it.

## Compose Runtime Flow

When `make init` or `make up` runs Docker Compose, Compose builds the custom Airflow
image from the Dockerfile. The Dockerfile exports the locked production dependency set
from `pyproject.toml` and `uv.lock`, then installs it into the image with `uv`. Compose
uses that image for the Airflow services and starts Postgres alongside them.

```text
docker compose
    -> Dockerfile
             -> pyproject.toml + uv.lock
             -> uv export + uv pip install
             -> airflow-versioning-demo image
    -> Postgres + Airflow API server, scheduler, DAG processor, and triggerer
```

Open `http://localhost:8080` and sign in with the credentials in `.env` (the defaults
are `airflow` / `airflow`). This demo uses Airflow 3's development-only
`SimpleAuthManager`; `make init` writes its shared password file to `config/`.
Confirm all containers are healthy with:

```sh
docker compose ps
curl --fail http://localhost:8080/api/v2/monitor/health
```

The DAG processor refreshes the local Git bundle every five seconds. Follow it while
working with `make logs`.

## DAG Version Behavior

Airflow identifies a DAG by `dag_id`. The table below assumes the same `dag_id` has a
historical v1 run and that v2 is now the current parsed version from `main`.

| Situation | Can choose a version? | Version that executes |
| --- | --- | --- |
| Trigger a new upcoming run in the UI | No | Current parsed version, v2 |
| Trigger a new upcoming run using v1 while v2 is current | No | Deploy or configure GitDagBundle to track v1 first, then trigger the run |
| Automatic retry of a task in an existing v1 run | No | The run's recorded v1 |
| Clear or rerun an existing v1 run | Yes: leave **Run with latest DAG version** unselected | The run's recorded v1 |
| Clear or rerun an existing v1 run | Yes: select **Run with latest DAG version** | Current parsed version, v2 |
| Inspect a historical v1 run in Graph, Grid, or Code views | Yes: select the historical run | Its recorded v1 definition |
| Create a backfill | Yes: choose original or latest behavior | Controlled by `run_on_latest_version` and `rerun_with_latest_version`; not an arbitrary historical-version picker |

To make future new runs use v1 again, deploy v1 as the current version, for example by
reverting the v2 Git commit. Airflow DAG versioning preserves and reuses versions for
existing runs; it does not provide a UI selector for an arbitrary historical version on
a newly created run.

## Versioning Exercise

### 1. Run v1

The initial `dags/versioned_demo.py` has one task, `report_version`, which logs `v1`.
In the Airflow UI:

1. Open `http://localhost:8080`, then select `versioned_demo` from the DAG list.
2. Select the **Runs** tab and click the trigger icon.
3. Confirm the trigger dialog without a configuration payload.
4. Open the new run, select `report_version`, and open its logs. Confirm the log says
    `versioned_demo is executing v1`.

Record the run ID and keep this v1 run for step 3. To inspect its stored Git commit,
run `make version-info`; the `bundle_version` column is the commit stored for the run.

### 2. Create and run v2

Edit `dags/versioned_demo.py` to make a deliberate new version. For example, change
`version = "v1"` to `version = "v2"`, add `"v2"` to its tags, and add this task after
`report_version()`:

```python
    @task
    def publish_version(version: str) -> None:
        print(f"published {version}")

    publish_version(report_version())
```

Commit the change and wait for the DAG processor to refresh it:

```sh
git add dags/versioned_demo.py
git commit -m "Demonstrate DAG v2"
make logs
```

In the Airflow UI, refresh the `versioned_demo` DAG page until the graph includes
`publish_version`. Then select the **Runs** tab, click the trigger icon, and confirm
the dialog. Open the new run and its task logs to confirm it uses v2. Optionally run
`make version-info` to verify that this run has a different `bundle_version`.

### 3. Prove the old run stays on v1

In the Airflow UI:

1. Return to the v1 run you recorded in step 1 and select `report_version`.
2. Click **Clear**.
3. Leave **Run with latest DAG version** unselected, then confirm the clear dialog.
4. Open `report_version` after it runs again. Its log says `v1`, even though v2 is
    currently deployed, and the v2-only `publish_version` task is not part of this run.

The run retains its original `bundle_version`. The DAG sets
`rerun_with_latest_version=False` explicitly, making the original-version behavior the
default.

`make version-info` queries the Airflow metadata database directly and shows the bundle
name and Git commit recorded by every `versioned_demo` run.

## Local Python Development

`pyproject.toml` and `uv.lock` are the only dependency definitions. `uv` manages the
local environment for editing, linting, and DAG import tests, and the Docker build
exports its locked production dependencies and installs them with `uv` into the
Airflow image.

```sh
make lint
make test
```

## Lifecycle

```sh
make down    # Stop services and preserve Postgres data
make reset   # Remove containers and the Postgres volume
```

The DAG source remains local in `dags/`. The whole project is mounted read-only at
`/opt/airflow/project` inside each Airflow container, allowing `GitDagBundle` to clone
the local repository without a hosted Git service or stored credentials.

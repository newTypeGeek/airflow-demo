from __future__ import annotations

from datetime import datetime

from airflow.sdk import dag, task


@dag(
    dag_id="versioned_demo",
    description="Shows GitDagBundle version-pinned DAG runs.",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["demo", "versioning", "v2"],
    rerun_with_latest_version=False,
)
def versioned_demo():
    @task
    def report_version() -> str:
        version = "v2"
        print(f"versioned_demo is executing {version}")
        return version

    report_version()


versioned_demo = versioned_demo()

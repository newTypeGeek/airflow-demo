import runpy
from pathlib import Path


def test_versioned_demo_has_initial_v1_graph() -> None:
    dag_file = Path(__file__).parents[1] / "dags" / "versioned_demo.py"

    namespace = runpy.run_path(dag_file)
    dag = namespace["versioned_demo"]

    assert dag.dag_id == "versioned_demo"
    assert dag.task_ids == ["report_version"]
    assert dag.rerun_with_latest_version is False

# Make sure the virtual environment is activated
PYTHON_VENV=.venv
source activate $PYTHON_VENV/bin/activate

AIRFLOW_VERSION=2.5.2
PYTHON_VERSION="$(python --version | cut -d " " -f 2 | cut -d "." -f 1-2)" # extract python version from virtual environment
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-no-providers-${PYTHON_VERSION}.txt"

# Install airflow to local virtual environment
pip install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"

# Make sure the virtual environment is activated
PYTHON_VENV=.venv
source $PYTHON_VENV/bin/activate

export AIRFLOW_HOME="$(pwd)/airflow"  # airflow working directory
export AIRFLOW__CORE__LOAD_EXAMPLES=False  # remove all example DAGs
export AIRFLOW__CORE__DAGS_FOLDER="$(pwd)/src/dags"  # DAGs directory

# Initialize the database
airflow db init

# Create an admin user
airflow users create \
    --username admin \
    --password admin \
    --firstname FIRST_NAME \
    --lastname LAST_NAME \
    --role Admin \
    --email admin@example.com

# Start the web server, default port is 8080
airflow webserver -p 8080

# Start the scheduler
airflow scheduler

# Visit 0.0.0.0:8080 in the browser and use the admin credentials to login
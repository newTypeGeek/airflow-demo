# remove DAG examples in airflow
export AIRFLOW__CORE__LOAD_EXAMPLES=False

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

# Visit 0.0.0.0:8080 in the browser and use the admin credentials to login.
# The default airflow directory is located at ~/airflow
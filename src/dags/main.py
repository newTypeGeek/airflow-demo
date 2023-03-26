import datetime

from airflow.decorators import dag, task

import requests
import json
import os

RAW_DATA_DIR = "raw_data"

@dag(
    # per minute schedule
    schedule_interval="@minute",
    start_date=datetime.datetime(2021, 1, 1),
    tags=["etl_demo"],
)
def etl_demo():

    # get request of HKO weather data and store to local file
    @task("hko_weather_to_local")
    def hko_weather_to_local():
        # get weather data from HKO
        url = "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=rhrread&lang=en"
        try:
            response = requests.get(url)
        except requests.exceptions.RequestException as e:
            raise e
        
        if not response.ok:
            response.raise_for_status()
        
        data = response.json()

        # must have updateTime
        if "updateTime" not in data:
            raise ValueError("updateTime not found in data")
        
        # save the data as json only if updateTime is not in the file
        update_time = data["updateTime"]
        file_path = os.path.join(RAW_DATA_DIR, f"{update_time}.json")
        if not os.path.exists(file_path):
            with open(file_path, "w") as f:
                json.dump(data, f, indent=4)
            print("Saved {file_path} successfully")
        else:
            print("File {file_path} already exists with the same updateTime={update_time}")
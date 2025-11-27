#!/bin/bash
adb push app_database.db /data/data/com.example.finanalyzer/databases/app_database.db
adb shell run-as com.example.finanalyzer chmod 600 /data/data/com.example.finanalyzer/databases/app_database.db

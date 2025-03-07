#!/bin/bash
pip install -r requirements.txt -t ./package
cp backup-service.py ./package
zip -r backup-service.zip ./package 
#!/bin/bash
aws secretsmanager create-secret \
    --name example-sftp-credentials \
    --description "SFTP credentials for accessing the SFTP host that has files to backup on S3" \
    --secret-string '{"SFTP_HOST": "sftp.example.com", "SFTP_USER": "your_username", "SFTP_PASSWORD": "your_password"}'
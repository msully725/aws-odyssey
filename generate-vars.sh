#!/bin/bash
# Get the IP and store it in a .tfvars file
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars

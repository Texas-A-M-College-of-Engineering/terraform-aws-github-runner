#!/usr/bin/env bash

# Sleep for 5 minutes
sleep 300

# Update the system
yum update -y

# Shutdown
shutdown -h now
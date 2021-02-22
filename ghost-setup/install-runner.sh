#!/usr/bin/env bash

if [ $# -lt 4 ]
then
  echo "Usage: ${0}: <github HTTP URL (shouldn't end in .git)> <Runner name> <Runner label> <registration token>"
  exit 1
fi
GITHUB_URL="${1}"
RUNNER_NAME="${2}"
RUNNER_LABEL="${3}"
TOKEN="${4}"

# If the runner is already set up, don't install it again
systemctl list-unit-files --type service --full | grep 'actions\.runner' 2>&1 > /dev/null
if [ $? -ne 0 ]
then

  LATEST_TAG=$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  LATEST_VERSION=$(echo "${LATEST_TAG}" | sed -e 's/^v//')

  cd /home/ec2-user
  if [ ! -d actions-runner ]
  then
    mkdir actions-runner
  fi
  cd actions-runner
  RUNNER_FILENAME=actions-runner-linux-x64-${LATEST_VERSION}.tar.gz
  if [ ! -f ${RUNNER_FILENAME} ]
  then
    curl -O -L https://github.com/actions/runner/releases/download/${LATEST_TAG}/${RUNNER_FILENAME}
  fi
  tar xzf ./${RUNNER_FILENAME}
  ./config.sh --url ${GITHUB_URL} --token ${TOKEN} --unattended --work "_work" --labels ${RUNNER_LABEL} --name ${RUNNER_NAME}
  sudo ./svc.sh install ec2-user
else
  echo "runner already installed... skipping"
fi

# Ensure that the service is enabled and started
SERVICE=$(systemctl list-unit-files --type service --full | grep 'actions\.runner' | cut -d' ' -f1)
sudo systemctl enable $SERVICE
sudo systemctl start $SERVICE
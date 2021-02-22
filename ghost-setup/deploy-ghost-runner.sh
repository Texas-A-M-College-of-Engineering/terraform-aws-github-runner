#!/usr/bin/env bash

## Note: you need to have the AWS SSM plugin configured for this to work
## See: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html

## Note: you need to have jwt-cli installed for this to work
## See: https://github.com/mike-engel/jwt-cli

# Read the environment variable value from the terraform.tfvars file
#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
GHOST_TAG=ghost-$(egrep '^environment = ' ${DIR}/terraform.tfvars | awk -F' = ' '{print $2}' | sed -e 's/"//g')
RUNNER_LABEL=$(egrep '^runner_extra_labels = ' ${DIR}/terraform.tfvars | awk -F' = ' '{print $2}' | sed -e 's/"//g')
KEY_BASE64=$(egrep '^ *key_base64 = ' ${DIR}/github-secrets.auto.tfvars | awk -F' = ' '{print $2}' | sed -e 's/"//g')
ISS=$(egrep '^ *id = ' ${DIR}/github-secrets.auto.tfvars | awk -F' = ' '{print $2}' | sed -e 's/"//g')


if [ $# -lt 2 ]
then
  echo "Usage: ${0} <EC2 Instance RSA key path> <GitHub repo HTTP URL>"
  exit 1
fi
PRIVATE_KEY="${1}"
GITHUB_URL_RAW="${2}"
GITHUB_URL="$(echo "${GITHUB_URL_RAW}" | sed -e 's/\.git$//')"



echo "Looking for EC2 Instance ID with tag: ${GHOST_TAG}"
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=${GHOST_TAG}" \
  --query 'Reservations[-1].Instances[-1].InstanceId' \
  --output text)

if [[ -z "${INSTANCE_ID}" ]]
then
  echo "Failed to find an Instance ID that matched the tag... aborting"
   exit 2
fi
echo "Setting up ghost runner to Instance ID: ${INSTANCE_ID}"


### Get the registration token (which lasts for one hour) for registering the runner ###

# Take the BASE64 key string, decode it back to the usual base64 PEM text, then decode it again into binary and write to a file
echo "${KEY_BASE64}" | base64 --decode | grep -v '\-\-\-' | base64 --decode > /tmp/github.binary.key

let NOW=$(date "+%s")
let HOUR_LATER=$((${NOW}+(10*60)))
# Get a valid JWT for authentication
JWT=$(jwt encode -i 100014 -A RS256 --secret @/tmp/github.binary.key --nbf ${NOW} --exp ${HOUR_LATER})
# Get the installation id of the GitHub app
INSTALLATION_ID=$(curl --silent -H "Authorization: Bearer ${JWT}" -H "Accept: application/vnd.github.v3+json" \
                  https://api.github.com/app/installations | jq '.[0]["id"]')

# Get an installation access token
INSTALLATION_TOKEN=$(curl --silent -X POST \
                      -H "Authorization: Bearer ${JWT}" \
                      -H "Accept: application/vnd.github.v3+json" \
                      https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens | jq -r '.token')
GITHUB_URL="https://github.com/Texas-A-M-College-of-Engineering/engr-account-lifecycle"
OWNER_AND_REPO="$(echo "${GITHUB_URL}" | sed -e 's#https://github.com/##')"
# Get the runner registration token
RUNNER_REGISTRATION_TOKEN=$(curl --silent -X POST \
                            -H "Authorization: token ${INSTALLATION_TOKEN}" \
                            -H "Accept: application/vnd.github.v3+json" \
                            https://api.github.com/repos/${OWNER_AND_REPO}/actions/runners/registration-token | jq -r '.token')


if [[ -z "${RUNNER_REGISTRATION_TOKEN}" ]]
then
  echo "Failed to acquire GitHub Actions runner registration token... aborting"
  exit 2
fi


# Set up the github action runner
echo "Copying GitHub action runner set up script"
scp -i ${PRIVATE_KEY} ${DIR}/../ghost-setup/install-runner.sh ec2-user@${INSTANCE_ID}:
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi
echo "Installing GitHub action runner and setting up service"
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} "bash /home/ec2-user/install-runner.sh '${GITHUB_URL}' '${GHOST_TAG}' \
  '${RUNNER_LABEL}' '${RUNNER_REGISTRATION_TOKEN}' && \
  rm -f /home/ec2-user/install-runner.sh"
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi


# Set up the SystemD custom target
echo "Copying update-and-shutdown.target file"
scp -i ${PRIVATE_KEY} ${DIR}/../ghost-setup/update-and-shutdown.target ec2-user@${INSTANCE_ID}:
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi
echo "Copying update-sleep-and-shutdown.service file"
scp -i ${PRIVATE_KEY} ${DIR}/../ghost-setup/update-sleep-and-shutdown.service ec2-user@${INSTANCE_ID}:
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi
echo "Copying update-sleep-and-shutdown.sh script file"
scp -i ${PRIVATE_KEY} ${DIR}/../ghost-setup/update-sleep-and-shutdown.sh ec2-user@${INSTANCE_ID}:
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi

echo "Moving update-and-shutdown.target file into place and setting owner to root"
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} sudo mv -f /home/ec2-user/update-and-shutdown.target /etc/systemd/system/
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} sudo chown root:root /etc/systemd/system/update-and-shutdown.target
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi

echo "Creating directory update-and-shutdown.target.wants, copying update-sleep-and-shutdown.service to it, and setting owner to root"
TARGET_WANTS=/etc/systemd/system/update-and-shutdown.target.wants
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} "sudo test -d ${TARGET_WANTS} || sudo mkdir ${TARGET_WANTS}"
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} sudo mv -f /home/ec2-user/update-sleep-and-shutdown.service /etc/systemd/system/update-and-shutdown.target.wants
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} sudo chown root:root /etc/systemd/system/update-and-shutdown.target.wants/update-sleep-and-shutdown.service
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi

echo "Creating directory for script file update-sleep-and-shutdown.sh, move into place, and set ownership to root"
SCRIPT_DIR=/opt/ghost/bin
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} "sudo test -d ${SCRIPT_DIR} || sudo mkdir -p ${SCRIPT_DIR}"
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} "sudo mv -f /home/ec2-user/update-sleep-and-shutdown.sh ${SCRIPT_DIR}/ && chmod +x ${SCRIPT_DIR}/update-sleep-and-shutdown.sh"
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} sudo chown -R root:root ${SCRIPT_DIR}
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi

echo "Performing daemon-reload"
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} sudo systemctl daemon-reload
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi


echo "Setting new custom target update-and-shutdown.target as default target"
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} sudo ln -sf /etc/systemd/system/update-and-shutdown.target /etc/systemd/system/default.target
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi

echo "Switching to update, sleep, and shutdown target"
ssh -i ${PRIVATE_KEY} ec2-user@${INSTANCE_ID} sudo systemctl isolate update-and-shutdown.target
if [ $? -ne 0 ]
then
  echo "Failure... aborting"
   exit 3
fi



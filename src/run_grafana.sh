#!/bin/bash

set -eu

AUTO_PROVISION=$1
ARTIFACTS_DECOMPRESSED_PATH=$2
CONTAINER_NAME=$3
GRAFANA_PORT=$4
BRIDGE_NETWORK=$5
GRAFANA_MOUNT_PATH=$6
SECRET_ARN=$7
SERVER_PROTOCOL=$8
GENERATE_SELFSIGNED_CERT=$9
GRAFANA_INTERFACE=${10}

if [[ -z $AUTO_PROVISION \
	|| -z $ARTIFACTS_DECOMPRESSED_PATH \
	|| -z $CONTAINER_NAME \
	|| -z $GRAFANA_PORT \
	|| -z $BRIDGE_NETWORK \
	|| -z $GRAFANA_MOUNT_PATH \
	|| -z $SERVER_PROTOCOL \
	|| -z $GENERATE_SELFSIGNED_CERT \
	|| -z $GRAFANA_INTERFACE ]]; then
  echo 'Missing one or more arguments when trying to setup Grafana!'
  exit 1
fi

validate_password(){
  GRAFANA_PASSWORD=$1
  if [[ ${#GRAFANA_PASSWORD} -ge 16 && "$GRAFANA_PASSWORD" == *[A-Z]* && "$GRAFANA_PASSWORD" == *[a-z]* && "$GRAFANA_PASSWORD" == *[0-9]* && "$GRAFANA_PASSWORD" == *[#$@%+*\&!^]* ]]; then
    echo "Validated password successfully."
  else
    echo "Password must contain at least 16 characters, uppercase and lowercase letters, numbers, and special characters."
    exit 1
  fi
}

if [ "$AUTO_PROVISION" == "false" ]; then

	echo "Auto-provisioning is disabled, starting container without provisioning..."
	docker run -d \
	-p $GRAFANA_INTERFACE:$GRAFANA_PORT:3000 \
	--network=$BRIDGE_NETWORK \
	--name $CONTAINER_NAME \
	-v $GRAFANA_MOUNT_PATH/grafana:/var/lib/grafana \
	-e GF_SERVER_PROTOCOL=https \
  	-e GF_SERVER_CERT_FILE=/etc/ssl/certs/grafana.crt \
  	-e GF_SERVER_CERT_KEY=/etc/ssl/certs/grafana.key \
  	grafana/grafana:8.2.0


# If auto-provisioning, provision the container with credentials
elif [ "$AUTO_PROVISION" == "true" ]; then

	if [[ -z $SECRET_ARN ]];then
		echo 'Missing secret arn for auto-provisioning!'
		exit 1
	fi

	#If secrets do not already exist
	if [[ ! -s $GRAFANA_MOUNT_PATH/greengrass_grafana_secrets/admin_password ]];then

		#Retrieve username/password credentials
		echo "Setting up Grafana with provided credentials..."
		GRAFANA_CREDENTIALS=$(python3 $ARTIFACTS_DECOMPRESSED_PATH/retrieveGrafanaSecrets.py --secret_arn $SECRET_ARN )
		GRAFANA_CREDENTIALS_ARRAY=($GRAFANA_CREDENTIALS)
		GRAFANA_USERNAME=${GRAFANA_CREDENTIALS_ARRAY[0]}
		GRAFANA_PASSWORD=${GRAFANA_CREDENTIALS_ARRAY[1]}
		validate_password $GRAFANA_PASSWORD

		#Store these secrets as files in $MOUNT_PATH/greengrass_grafana_secrets
		echo $GRAFANA_USERNAME > $GRAFANA_MOUNT_PATH/greengrass_grafana_secrets/admin_username
		echo $GRAFANA_PASSWORD > $GRAFANA_MOUNT_PATH/greengrass_grafana_secrets/admin_password

		echo "Saved Grafana secrets to $GRAFANA_MOUNT_PATH/greengrass_grafana_secrets"
	else 
		echo "Reusing existing Grafana setup..."
	fi

	#Start the container, mount the secrets and tell Grafana where to look for the secrets
	#Also mount the artifact decompressed path in order to load in data sources
	echo "Creating a provisioned Grafana container and mounting specified paths..."

	if [ $SERVER_PROTOCOL == "https" ]; then

		echo "Creating new Grafana container with HTTPS..."

		docker run -d \
		-p $GRAFANA_INTERFACE:$GRAFANA_PORT:3000 \
		--network=$BRIDGE_NETWORK \
		--name $CONTAINER_NAME \
		-v $GRAFANA_MOUNT_PATH/grafana:/var/lib/grafana \
		-v $GRAFANA_MOUNT_PATH/greengrass_grafana_secrets:/var/lib/greengrass_grafana_secrets \
		-v $GRAFANA_MOUNT_PATH/grafana_certs:/var/lib/grafana/ssl/greengrass:ro \
		-v $ARTIFACTS_DECOMPRESSED_PATH/greengrass_grafana_dashboard:/var/lib/greengrass_grafana_dashboard \
		-v $ARTIFACTS_DECOMPRESSED_PATH/datasources:/etc/grafana/provisioning/datasources \
		-e GF_SECURITY_ADMIN_USER__FILE=/var/lib/greengrass_grafana_secrets/admin_username \
		-e GF_SECURITY_ADMIN_PASSWORD__FILE=/var/lib/greengrass_grafana_secrets/admin_password \
		-e GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/greengrass_grafana_dashboard/greengrass_grafana_dashboard.json \
		-e GF_SERVER_PROTOCOL=https \
	  	-e GF_SERVER_CERT_FILE=/var/lib/grafana/ssl/greengrass/grafana.crt \
	  	-e GF_SERVER_CERT_KEY=/var/lib/grafana/ssl/greengrass/grafana.key \
		grafana/grafana:8.2.0

	elif [ $SERVER_PROTOCOL == "http" ]; then
		echo "Creating new Grafana container with HTTP..."

		docker run -d \
		-p $GRAFANA_INTERFACE:$GRAFANA_PORT:3000 \
		--network=$BRIDGE_NETWORK \
		--name $CONTAINER_NAME \
		-v $GRAFANA_MOUNT_PATH/grafana:/var/lib/grafana \
		-v $GRAFANA_MOUNT_PATH/greengrass_grafana_secrets:/var/lib/greengrass_grafana_secrets \
		-v $ARTIFACTS_DECOMPRESSED_PATH/greengrass_grafana_dashboard:/var/lib/greengrass_grafana_dashboard \
		-v $ARTIFACTS_DECOMPRESSED_PATH/datasources:/etc/grafana/provisioning/datasources \
		-e GF_SECURITY_ADMIN_USER__FILE=/var/lib/greengrass_grafana_secrets/admin_username \
		-e GF_SECURITY_ADMIN_PASSWORD__FILE=/var/lib/greengrass_grafana_secrets/admin_password \
		-e GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/greengrass_grafana_dashboard/greengrass_grafana_dashboard.json \
		grafana/grafana:8.2.0
	fi

else
	echo "Invalid argument for AutoProvision, must be either true or false. Exiting..."
	exit 1
fi

echo "Grafana is running on port $GRAFANA_PORT..."
#This will keep the component running and retrieving Docker logs
docker logs --follow $CONTAINER_NAME 2>&1
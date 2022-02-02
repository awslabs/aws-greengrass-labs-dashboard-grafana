
## Greengrass Labs Grafana Component - `aws.greengrass.labs.dashboard.Grafana`

## Overview
This AWS IoT Greengrass component allows you to provision and manage a local [Grafana instance](https://grafana.com/grafana/) on your device.

At a high level, the component will do the following:

1. Pull down the official Grafana Docker image from Dockerhub.
2. Create new self-signed certificates and use them for HTTPS. You can toggle on/off both the certificate generation and HTTPS support separately, in case you would like to bring your own certificates to use with HTTPS, or if you would like to just use HTTP.
3. Retrieve a pre-configured secret containing a username and password from AWS Secret Manager via the `aws.greengrass.SecretManager` Greengrass component. These secrets will be used to setup Grafana.
4. Create a new Grafana container using the self-signed certificates and retrieved username/password, persisting data by mounting it to a location of your choice on your host machine.
5. Load in a specified data source (the default provided is InfluxDB).
6. Load in a premade dashboard to render Greengrass telemetry.

This component works with the `aws.greengrass.labs.dashboard.InfluxDBGrafana`, `aws.greengrass.labs.telemetry.InfluxDBPublisher` and `aws.greengrass.labs.database.InfluxDB` components to persist and visualize Greengrass System Telemetry data, but can be used on its own or as a primitive for any application.

* [aws.greengrass.labs.telemetry.InfluxDBPublisher](https://github.com/awslabs/aws-greengrass-labs-telemetry-influxdbpublisher)
* [aws.greengrass.labs.database.InfluxDB](https://github.com/awslabs/aws-greengrass-labs-database-influxdb)
* [aws.greengrass.labs.dashboard.InfluxDBGrafana](https://github.com/awslabs/aws-greengrass-labs-dashboard-influxdb-grafana)

![Architecture - Component](images/grafana.png)

## Configuration
The `aws.greengrass.labs.dashboard.Grafana` component supports the following configuration options. By default, `AutoProvision` is set to `True`, which will require you to provide the configuration for `SecretArn` but leave the remainder of the configuration as the default.

* `AutoProvision` - Retrieves a username/password from Secret Manager in order to provision Grafana. If turned off, an Grafana instance will still be set up, but you will need to [provision the instance on your own](https://grafana.com/docs/grafana/latest/installation/docker/).
    * (`true`|`false`)
    * default: `true`


* `SecretArn` - The ARN of the AWS Secret Manager secret containing your desired Grafana username/password. You must configure and deploy this secret with the [Secret manager component](https://docs.aws.amazon.com/greengrass/v2/developerguide/secret-manager-component.html), and you must specify this secret in the `accessControl` configuration parameter to allow this component to use it.
    * (`string`)
    * default: `arn:aws:secretsmanager:<region>:<account>:secret:<name>`


* `GrafanaMountPath` - Absolute path of a directory on your host machine that will be used to persist Grafana data and certs.
    * (`string`)
    * default: `/home/ggc_user/dashboard`


* `GrafanaContainerName` - The name of the Grafana Docker container.
    * (`string`)
    * default:  `greengrass_Grafana`


* `GrafanaInterface` - The IP for the Grafana container to bind on.
    * (`string`)
    *  default: `127.0.0.1`


* `GrafanaPort` -The port for the Grafana Docker container to bind to.
    *  (`string`)
    * default: `3000`


* `BridgeNetworkName` - The Docker bridge network to create and use for the Grafana Docker container.
    * (`string`)
    * default:`greengrass-telemetry-bridge`


* `ServerProtocol`- The protocol to use.
    *  (`https` | `http`)
    *  default: `https`


* `GenerateSelfSignedCert` - Generates self-signed certs for HTTPS if they do not already exist. If set to false while using HTTPS, the component will look for the following two files to use: `{configuration:/GrafanaMountPath}/grafana_certs/grafana.crt` and `{configuration:/GrafanaMountPath}/grafana_certs/grafana.key`
    * (`true` | `false` )
    *  default: `true`


* `SkipTLSVerify`: Skip TLS verification (if using self-signed certificates for HTTPS).
    * (`true` | `false` )
    *  default: `true`


* `HTTPSCertExpirationDays` - The number of days you would like the auto-generated self-signed certificates to be valid for.
    * (`string`)
    *  default: `365`


* `accessControl` - [Greengrass Access Control Policy](https://docs.aws.amazon.com/greengrass/v2/developerguide/interprocess-communication.html#ipc-authorization-policies), required for secret retrieval.
    * A incomplete `accessControl` policy allowing secret retrieval has been included, which you will need to configure.

## Setup
**The following steps are for Ubuntu 20.04 x86_64, but will be similar for most platforms.**

### Prerequisites
1. Install dependencies on the host machine.
    ```
   sudo apt-get update; sudo apt-get install -y \
     ca-certificates \
     curl \
     gnupg \
     lsb-release \
     zip \
     default-jre \
     python3-pip; \
   python3 -m pip install awsiotsdk
    ```
2. Install Docker on the host machine using [the instructions for Ubuntu](https://docs.docker.com/engine/install/ubuntu/):
   ```
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \ $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io
   ```

3. Setup AWS IoT Greengrass on the host machine [according to the installation instructions](https://docs.aws.amazon.com/greengrass/v2/developerguide/install-greengrass-core-v2.html):
4. Log in as superuser with `sudo su` and then allow `ggc_user:ggc_group` to use Docker, [as per the Docker documentation](https://docs.docker.com/engine/install/linux-postinstall/):
   ```
      sudo usermod -aG docker ggc_user; newgrp docker 
   ```
   Test your access with first `sudo su` and then `su - ggc_user -c "docker ps"`

### Component Setup
1. Install [the Greengrass Development Kit CLI](https://docs.aws.amazon.com/greengrass/v2/developerguide/install-greengrass-development-kit-cli.html) in your local workspace.
    1. Run `python3 -m pip install git+https://github.com/aws-greengrass/aws-greengrass-gdk-cli.git`
2. Pull down the component in a new directory using the GDK CLI.
    ```
    mkdir aws-greengrass-labs-dashboard-grafana; cd aws-greengrass-labs-dashboard-grafana
    gdk component init --repository aws-greengrass-labs-dashboard-grafana
    ```
3. Create an AWS Secrets Manager Secret to store your Grafana username/password.
    1. Go to [AWS Secrets Manager](https://console.aws.amazon.com/secretsmanager/home?region=us-east-1#!/listSecrets):
    2. Create new secret → Other type of Secret → Plaintext. The secret you use should be in the following format:
       ```
       {
        "grafana_username": "myGrafanaDBUsername",
        "grafana_password": "myGrafanaPassword123!"
       }
       ```
       Note that your password **must** be at least 16 characters long and must include uppercase and lowercase letters, numbers, and special characters.

    3. Note down the ARN of the secrets you just made.

4. Authorize Greengrass to retrieve this secret using IAM:
    1. Follow [the Greengrass documentation](https://docs.aws.amazon.com/greengrass/v2/developerguide/device-service-role.html) to add authorization
    2. See the [`aws.greengrass.SecretManager` documentation for more information.](https://docs.aws.amazon.com/greengrass/v2/developerguide/secret-manager-component.html)
    3. Your policy should include `secretsmanager:GetSecretValue` for the secret you just created.
    ```
        {
        "Version": "2012-10-17",
        "Statement": [
                "Sid": "VisualEditor1",
                "Effect": "Allow",
                "Action": "secretsmanager:GetSecretValue",
                "Resource": [
                    "<grafana secret arn>"
                ]
            }
        ]
    }
    ```
    4. If you already have a similar policy attached for `aws.greengrass.labs.database.InfluxDB`, you can just add this new ARN as follows:
    ```
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": "secretsmanager:GetSecretValue",
              "Resource": [
                  "<influxDB secret arn>",
                  "<grafana secreet arn>"
              ]
          }
      ]
      }
    ```

5. (OPTIONAL) Connect to InfluxDB or another data source

    If you would like to have Grafana connect to InfluxDB automatically, you should skip this step and use the [aws.greengrass.labs.dashboard.InfluxDBGrafana]([aws.greengrass.labs.dashboard.InfluxDBGrafana](https://github.com/awslabs/aws-greengrass-labs-dashboard-influxdb-grafana)) component, which automates setup to provide a "one-click" experience.

	  If you would like to manually add a datasource via a mount, you can do so as follows. The following example is for InfluxDB. 
   

	  In order to add a datasource, add your datasource file to the `src/datasources` folder. It will be mounted into `/etc/grafana/provisioning/datasources` inside the container for Grafana to automatically pick up.
	  See the [Grafana documentation on adding data source files](https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources) for more information.
	  1. First, you must create a new read-only token in order to connect to InfluxDB. Follow [the documentation here](https://github.com/awslabs/aws-greengrass-labs-database-influxdb/blob/development/README.md#influxdb-token-creation) to create one.
	     1. We provide two datasource file templates for you to use to connect to InfluxDB. Use the appropriate file, depending on whether your InfluxDB instance uses http or https.
	        * `influxdb-datasource_http.yaml.template`
	          * Replace `$GREENGRASS_INFLUXDB_TOKEN` with your retrieved token.
	          * Rename the file to `influxdb-datasource_http.yaml`
	        * `influxdb-datasource_https.yaml.template`
	          * Replace `$GREENGRASS_INFLUXDB_TOKEN` with your retrieved token.
	          * Replace `$TLS_CLIENT_CERT` with the contents of the InfluxDB .cert file present at `{configuration:/InfluxDBMountPath}/influxdb2_certs/influxdb.crt`
	          * Replace `$TLS_CLIENT_KEY` with the contents of the InfluxDB .key file present at `{configuration:/InfluxDBMountPath}/influxdb2_certs/influxdb.key`
	          * Rename the file to `influxdb-datasource_https.yaml`
	          * It should look something like this:

	          ```
	          apiVersion: 1

	          datasources:
	           - name: InfluxDB
	            type: influxdb
	            access: proxy
	            url: https://greengrass_influxDB:8086
	            editable: false
	            jsonData:
	                version: Flux
	                organization: greengrass
	                defaultBucket: greengrass-telemetry
	                tlsSkipVerify: true
	                tlsAuth: true
	                serverName: https://greengrass_influxDB:8086
	            secureJsonData:
	                token: T6ir...jAAXAtqPl7w==
	                tlsClientCert: |
	                    -----BEGIN CERTIFICATE-----
	                    MIIDazCCAlOgAwIBAgIUQtaacB3co2urJuMXHWUFYMEOvBMwDQYJKoZIhvcNAQEL
	                    ...
	                    4rHbn4WW6iedZQOl7WYx
	                    -----END CERTIFICATE-----
	                tlsClientKey: |
	                    -----BEGIN PRIVATE KEY-----
	                    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDWUylAfubs0oJl
	                    ...
	                    gD7L5zJLTpzdq23Y/3evLoE=
	                    -----END PRIVATE KEY-----
	            ```

6. Create the component:
    1. (OPTIONAL) Modify the `aws.greengrass.labs.dashboard.Grafana` recipe at `recipe.yaml`. NOTE: if you would like to specify this configuration during deployment, you can also specify this configuration during a deployment (see Step 7).
    2. Replace the two occurrences of `'arn:aws:secretsmanager:region:account:secret:name'` with your created secret ARN, including in the `accessControl` policy.
        1. (Optional) Specify a mount path. The default used will be `/home/ggc_user/dashboard`.
            1. When specifying a mount path, note that this mount path will be used to store sensitive data, including secrets and certs used for Grafana auth. You are responsible for securing this directory on your device. Ensure that `ggc_user:ggc_group` has read/write/execute access to this directory with the following command: `namei -m <path>`.
    3. Use the [GDK CLI](https://docs.aws.amazon.com/greengrass/v2/developerguide/greengrass-development-kit-cli.html) to build the component to prepare for publishing.
       ```
       gdk component build
       ```
       4. Use the [GDK CLI](https://docs.aws.amazon.com/greengrass/v2/developerguide/greengrass-development-kit-cli.html) to create a private component.
       ```
       gdk component publish
       ```
7.  Create deployment via the CLI or AWS Console, from [Greengrass documentation](https://docs.aws.amazon.com/greengrass/v2/developerguide/create-deployments.html). The following components should be configured in your deployment:
    1. `aws.greengrass.SecretManager`:
     ```
     "cloudSecrets": [
        {
          "arn": "<influxDB secret arn>"
        },
        {
          "arn": "<grafana secreet arn>"
        }
      ]
     ]
     ```
    If you are not using the `aws.greengrass.labs.database.InfluxDB` component, you can remove the InfluxDB secret arn from the above.
    2. If you would like to specify your mount path/Secret Arn/Access Control during deployment instead, ***you must first remove the entire accessControl section from the recipe.yaml file before you create the component***. Then, make sure to merge in the following configuration to your component configuration during deployment. Note that specifying a non-default mount path is optional, and omitting it will result in the component using `/home/ggc_user/dashboard` instead.
    ```
    {
         "GrafanaMountPath": "<Your mount path>" (Optional)
         SecretArn: "<Your secret ARN>"
         "accessControl": {
            "aws.greengrass.SecretManager": {
              "aws.greengrass.labs.dashboard.Grafana:secrets:1": {
                "operations": [
                  "aws.greengrass#GetSecretValue"
                ],
                "policyDescription": "Allows access to the secret containing Grafana credentials.",
                "resources": [
                  "arn:aws:secretsmanager:region:account:secret:name"
                ]
              }
         }
     }
    ```
4. View the component logs at `/greengrass/v2/logs/aws.greengrass.labs.dashboard.Grafana.log`.
    1. If correctly set up, you will see the messages `Grafana is running on port 3000` and `msg="HTTP Server Listen"`, and see logs from Grafana as it runs.
    2. You can also run `curl -k https://localhost:3000/api/health` to check the status:
   ```
      {
      "commit": "d7f71e9eae",
      "database": "ok",
      "version": "8.2.0"
      }
      ```

5. If you would like to forward the port from a remote machine, ssh in with the following command to forward the port:
   `ssh -L 3000:localhost:3000 ubuntu@<IP address>`
6. Visit `https://localhost:3000` to view Grafana, and login with your username and password.
7. If using self-signed certificates (the default), you will either need to add trust for these certificates, or possibly use your browser's incognito mode.
   Please see the Troubleshooting section to resolve any issues you may encounter.


## Component Lifecycle Management
* Grafana data will be persisted between container restarts and removals since it is mounted to the location of your choice on your host machine.
* Upon start, by default the component will look for the following and create them if they are not present:
    * The docker bridge network `greengrass-telemetry-bridge`
    * The directory `{configuration:/GrafanaMountPath}/grafana_certs` along with a `.cert` and `.key` file for HTTPS
        * By default, this directory has file permissions set to `077` for maximum compatability. [You are responsible for securing file permission on your device](https://docs.aws.amazon.com/greengrass/v2/developerguide/encryption-at-rest.html), and we would recommend scoping these permissions down to fit your use case.
    * The directories
        * `{configuration:/GrafanaMountPath}/grafana` to store Grafana data
        * `{configuration:/GrafanaMountPath}/greengrass_grafana_secrets` to store the retrieved Grafana secrets from AWS Secrets Manager.
    * See more information on [the Grafana Dockerhub page](https://hub.docker.com/r/grafana/grafana)
* You are free to modify and create more Grafana dashboards as needed to load in.

## Networking
* Please see the [Grafana Configuration Options](https://grafana.com/docs/grafana/latest/administration/configuration/) for a full list of networking options.
* By default, this component will create a [Docker Bridge Network](https://docs.docker.com/network/bridge/) named `greengrass-telemetry-bridge` for isolation. This also provides easier resolution between this component's container and others such as `aws.greengrass.labs.database.InfluxDB`.
* The component by default uses self-signed certificates to set up HTTPS with a TLS encryption. They do not allow clients to verify the identity of the Grafana server. Please see the [Grafana HTTPS Configuration Options](https://grafana.com/docs/grafana/latest/administration/configuration/#server) for more information.
* Please see the component configuration options for information on how to change the default port, IP to bind to, bridge network name and http/https, as well as the option to toggle the generation of self-signed certs and TLS verification.


## Container Security
* Greengrass does not manage or distribute the Grafana Docker image referenced in this Greengrass component. You are responsible for securing Docker containers on your device and ensuring it does not contain vulnerabilities or security risks.
* HTTPS support is turned on by default; if you would like to use only HTTP, set `ServerProtocol` to `http` in the component configuration.

* Consider using [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) with Grafana as directed in the [Grafana documentation](https://grafana.com/docs/grafana/latest/administration/configure-docker/#configure-grafana-with-docker-secrets).
    * The component will expect Grafana secrets to be present at
        * `{configuration:/GrafanaMountPath}/greengrass_grafana_secrets/admin_password` and
        * `{configuration:/GrafanaMountPath}/greengrass_grafana_secrets/admin_username`
    * Additional secrets for datasources are expected at `{artifacts:decompressedPath}/aws-greengrass-labs-dashboard-grafana/src/datasources`.

## Certificate Management and Expiry
* This component by default generates self-signed certificates to use for TLS encryption. We would recommend you sign your certificates with a Certificate Authority .
* If `GenerateSelfSignedCert` is set to false in the component configuration while using HTTPS, the component will look for the following two files to use, which you can provide:
    * `{configuration:/GrafanaMountPath}/grafana_certs/grafana.crt`
    * `{configuration:/GrafanaMountPath}/grafana_certs/grafana.key`
* The HTTPS certificates generated by default will expire in 365 days. If they are removed and the component redeployed or regenerated, new certificates will be created.


## Resources
* [AWS IoT Greengrass V2 Developer Guide](https://docs.aws.amazon.com/greengrass/v2/developerguide/what-is-iot-greengrass.html)
* [AWS IoT Greengrass V2 Community Components](https://docs.aws.amazon.com/greengrass/v2/developerguide/greengrass-software-catalog.html)
* [AWS IoT Greengrass Development Kit CLI](https://docs.aws.amazon.com/greengrass/v2/developerguide/greengrass-development-kit-cli.html)
* [Grafana Dockerhub](https://hub.docker.com/r/grafana/grafana)
* [Grafana Docker Documentation](https://grafana.com/docs/grafana/latest/installation/docker/)
* [Grafana Docker Image Configuration](https://grafana.com/docs/grafana/latest/administration/configure-docker/)
* [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
* [Grafana Configuration Options](https://grafana.com/docs/grafana/latest/administration/configuration/)

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.

## Troubleshooting
*
```
Could not import awsiot
```
Ensure that `ggc_user` can import this Python library by running first `sudo su` and then `su - ggc_user -c "python3 -c 'import awsiot'"`
*
```
mkdir: Operation not permitted
```
Ensure that your mount path has sufficient permission to create and mount directories into the container. If necessary, you can use `RequiresPrivilege: true` in the component recipe's lifecycle to run as root, although this is not recommended.
*
```
stdout. You may have issues with file permissions, more information here: http://docs.grafana.org/installation/docker/#migrate-to-v51-or-later. 
stdout. mkdir: can't create directory '/var/lib/grafana/plugins': Permission denied.
```
Ensure that your mount path has sufficient permission to create and mount directories into the container. If necessary, you can use `RequiresPrivilege: true` in the component recipe's lifecycle to run as root, although this is not recommended.
*
```
aws.greengrass.labs.dashboard.Grafana: stdout. *api.HTTPServer run error: open /var/lib/grafana/ssl/greengrass/grafana.crt: permission denied.

```
Docker/grafana cannot access the mounted https cert/key Ensure that your mount path has sufficient permission to create and mount directories into the container.
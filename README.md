## My Project

TODO: Fill this README out!

Be sure to:

* Change the title in this README
* Edit your repository description on GitHub

## Setup

When specifying a mount path, note that this mount path will be used to store sensitive data, including secrets and certs used for Grafana auth. You are responsible for securing this directory on your device. Ensure that the `ggc_user:ggc_group` has read/write/execute access to this directory with the following command: `namei -m <path>`.

Consider using [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) with Grafana as directed in the [Grafana documentation](https://grafana.com/docs/grafana/latest/administration/configure-docker/#configure-grafana-with-docker-secrets). The component will expect Grafana secrets to be present at `$GRAFANA_MOUNT_PATH/greengrass_grafana_secrets/admin_password` and `$GRAFANA_MOUNT_PATH/greengrass_grafana_secrets/admin_username`. Additional secrets for datasources are expected at `{artifacts:decompressedPath}/aws-greengrass-labs-dashboard-grafana/src/datasources`.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.


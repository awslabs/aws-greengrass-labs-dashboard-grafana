# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import argparse
import sys
import pytest
import json

sys.path.append("src/")


def test_parse_valid_args(mocker):
    mock_parse_args = mocker.patch(
        "argparse.ArgumentParser.parse_args", return_value=argparse.Namespace(secret_arn="arn:test:object")
    )
    import src.retrieveGrafanaSecrets as ris

    args = ris.parse_arguments()
    assert args.secret_arn == "arn:test:object"
    assert mock_parse_args.call_count == 1


def test_parse_no_args(mocker):
    import src.retrieveGrafanaSecrets as ris

    with pytest.raises(SystemExit) as pytest_wrapped_e:
        ris.parse_arguments()
    assert pytest_wrapped_e.type == SystemExit


def test_retrieve_secret_valid_response(mocker):
    testArn = {
        "grafana_username": "test_username",
        "grafana_password": "test_password"
    }
    mock_ipc_call = mocker.patch("src.retrieveGrafanaSecrets.get_secret_over_ipc", return_value=json.dumps(testArn))
    import src.retrieveGrafanaSecrets as ris
    result = ris.retrieve_secret("arn:test:object")
    assert result == 'test_username test_password'
    assert mock_ipc_call.call_count == 1
    mock_ipc_call.assert_any_call("arn:test:object")


def test_retrieve_secret_invalid_response(mocker):

    testArn = {
        "garbage value": "garbage"
    }
    mock_ipc_call = mocker.patch("src.retrieveGrafanaSecrets.get_secret_over_ipc", return_value=json.dumps(testArn))
    import src.retrieveGrafanaSecrets as ris
    with pytest.raises(KeyError, match='grafana_username'):
        ris.retrieve_secret("arn:test:object")
    assert mock_ipc_call.call_count == 1
    mock_ipc_call.assert_any_call("arn:test:object")


def test_retrieve_secret_empty_response(mocker):

    testArn = {}
    mock_ipc_call = mocker.patch("src.retrieveGrafanaSecrets.get_secret_over_ipc", return_value=json.dumps(testArn))
    import src.retrieveGrafanaSecrets as ris
    with pytest.raises(KeyError, match='grafana_username'):
        ris.retrieve_secret("arn:test:object")
    assert mock_ipc_call.call_count == 1
    mock_ipc_call.assert_any_call("arn:test:object")
#!/usr/bin/env bash

set -e

export CAMERA=/dev/video0
export NETWORK_TABLES_SERVER_ADDRESS=10.0.0.2
export VISION_CONFIG_FILE_PATH=./vision.json

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
pushd "${SCRIPT_DIR}"

poetry install
poetry run python3 main.py

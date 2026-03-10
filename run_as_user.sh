#!/usr/bin/env bash

# Exit on any error and treat unset variables as errors.
set -euo pipefail

OLD_UID="$1"
OLD_GID="$2"
shift 2

groupadd --gid "$OLD_GID" --non-unique user
useradd --uid "$OLD_UID" --gid "$OLD_GID" --non-unique user

sudo -E -u user "$@"
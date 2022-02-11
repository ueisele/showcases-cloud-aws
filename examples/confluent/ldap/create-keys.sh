#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(readlink -fe "$(dirname "${BASH_SOURCE[0]}")")"

CONFLUENT_VERSION=7.0.1

create_keys()
{

  # Generating public and private keys for token signing
  echo "Generating public and private keys for token signing"
  docker run -v ${SCRIPT_DIR}/security/:/etc/kafka/secrets/ -u0 confluentinc/cp-server:${CONFLUENT_VERSION} bash -c "mkdir -p /etc/kafka/secrets/keypair; openssl genrsa -out /etc/kafka/secrets/keypair/keypair.pem 2048; openssl rsa -in /etc/kafka/secrets/keypair/keypair.pem -outform PEM -pubout -out /etc/kafka/secrets/keypair/public.pem && chown -R $(id -u $USER):$(id -g $USER) /etc/kafka/secrets/keypair"

  # Enable Docker appuser to read files when created by a different UID
  echo -e "Setting insecure permissions on some files in ${SCRIPT_DIR}/../security for demo purposes\n"
  chmod 644 ${SCRIPT_DIR}/security/keypair/keypair.pem
}

create_keys
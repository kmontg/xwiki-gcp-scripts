#!/bin/sh

# Pre-requisite: PROJECT is defined
# Pre-requisite: ${PROJECT} exists in GCP with billing enabled.
if [[ -z "${PROJECT}" ]]; then
  echo "Set envvar PROJECT to your GCP project before running this script."
  exit 1
fi;

# Pre-requisite: gcloud is installed
if ! [ -x "$(command -v gcloud)" ]; then
  echo 'gcloud is required to run this script. Please install it before re-running.'
  exit 1
fi

# Pre-requisite: gsutil is installed
if ! [ -x "$(command -v gsutil)" ]; then
  echo 'gsutil is required to run this script. Please install it before re-running.'
  exit 1
fi

# Pre-requisite: authentication for Cloud SDK
ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
if [[ -z "${ACCOUNT}" ]]; then
  echo "Run 'gcloud auth login' to authenticate on GCP before running this script."
  exit 1
fi;

# Location settings
export LOCATION=us-central1
export ZONE=us-central1-c

# Artifact Registry repo and image
export MAVEN_REPO=xwiki-maven-repo
export DOCKER_REPO=xwiki-docker-repo

# Service Accounts
export BUILDER=builder
export BUILDER_SA="${BUILDER}@${PROJECT}.iam.gserviceaccount.com"
export BUILDER_KEY_FILE="./sa-private-key.json"

# xwiki release bucket
export BUCKET=xwiki-release

# GKE cluster
export CLUSTER=xwiki-cluster
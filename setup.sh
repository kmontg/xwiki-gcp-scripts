#!/bin/sh
set -e

dir=$(dirname $0)
. "${dir}"/env.sh

gcloud config set project "${PROJECT}"
gcloud services enable artifactregistry.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable logging.googleapis.com

existing_maven_repository=$(gcloud artifacts repositories \
                              list \
                              --format="value(name)" \
                              --filter="projects/${PROJECT}/locations/${LOCATION}/repositories/${MAVEN_REPO}" \
                              --limit=1)

if [[ -z "${existing_maven_repository}" ]]; then
  gcloud artifacts repositories \
    create \
    "${MAVEN_REPO}" \
    --location="${LOCATION}" \
    --repository-format="maven" \
    --version-policy="none" \
    --allow-snapshot-overwrites
fi; 

existing_docker_repository=$(gcloud artifacts repositories \
                              list \
                              --format="value(name)" \
                              --filter="projects/${PROJECT}/locations/${LOCATION}/repositories/${DOCKER_REPO}" \
                              --limit=1)

if [[ -z "${existing_docker_repository}" ]]; then
  gcloud artifacts repositories \
    create \
    "${DOCKER_REPO}" \
    --location="${LOCATION}" \
    --repository-format="docker"
fi; 

existing_sa=$(gcloud iam service-accounts \
                list \
                --format="value(email)" \
                --filter="email=${BUILDER_SA}" \
                --limit=1 \
            )

if [[ -z "${existing_sa}" ]]; then
  gcloud iam service-accounts create "${BUILDER}" \
    --description="AR Builder" \
    --display-name="AR Builder"
fi;

gcloud artifacts repositories \
    add-iam-policy-binding \
    "${MAVEN_REPO}" \
    --location="${LOCATION}" \
    --member="serviceAccount:${BUILDER_SA}" \
    --role='roles/artifactregistry.writer'

gcloud artifacts repositories \
    add-iam-policy-binding \
    "${DOCKER_REPO}" \
    --location="${LOCATION}" \
    --member="serviceAccount:${BUILDER_SA}" \
    --role='roles/artifactregistry.writer'

gcloud artifacts repositories \
    add-iam-policy-binding \
    "${MAVEN_REPO}" \
    --location="${LOCATION}" \
    --member="serviceAccount:${BUILDER_SA}" \
    --role='roles/artifactregistry.reader'

gcloud artifacts repositories \
    add-iam-policy-binding \
    "${DOCKER_REPO}" \
    --location="${LOCATION}" \
    --member="serviceAccount:${BUILDER_SA}" \
    --role='roles/artifactregistry.reader'

# Print maven settings to use when uploading to AR.
gcloud artifacts print-settings mvn \
    --repository="${MAVEN_REPO}" \
    --location=${LOCATION}

existing_bucket=$(gcloud storage buckets \
                    list \
                    --format="value(id)" \
                    --filter="id=${BUCKET}" \
                    --limit=1)

if [[ -z "${existing_bucket}" ]]; then
  gcloud storage buckets create gs://${BUCKET}/ \
    --uniform-bucket-level-access
fi;

gsutil iam \
  ch \
  serviceAccount:${BUILDER_SA}:objectAdmin \
  gs://${BUCKET}

existing_cluster=$(gcloud container clusters \
                    list \
                    --format="value(name)" \
                    --filter="name=${CLUSTER}" \
                    --limit=1)

if [[ -z "${existing_cluster}" ]]; then
  gcloud container clusters \
    create \
    "${CLUSTER}" \
    --zone="${ZONE}" \
    --service-account="${BUILDER_SA}"
fi;

gcloud projects add-iam-policy-binding \
  "${PROJECT}" \
	--member="serviceAccount:${BUILDER_SA}" \
	--role=roles/container.admin

gcloud projects add-iam-policy-binding \
  "${PROJECT}" \
	--member="serviceAccount:${BUILDER_SA}" \
	--role=roles/storage.admin

gcloud projects add-iam-policy-binding \
  "${PROJECT}" \
	--member="serviceAccount:${BUILDER_SA}" \
	--role=roles/container.clusterViewer

gcloud projects add-iam-policy-binding \
  "${PROJECT}" \
	--member="serviceAccount:${BUILDER_SA}" \
	--role=roles/container.nodeServiceAccount
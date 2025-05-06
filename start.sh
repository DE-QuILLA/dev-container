#!/bin/bash

image_name="dequila-image"
container_name="dequila-cont"
dockerfile_dir="."

CURR_DIR=$(pwd)

# Defaults 
infra_path="$CURR_DIR"
code_path="$CURR_DIR"
pk_path=""
# DO NOT USE SHIFT HERE! ❌

# Dashed args parsing
while getopts "i:c:m:k:h:" opt; do
    case $opt in
        i) infra_path="$OPTARG" ;;
        c) code_path="$OPTARG" ;;
        k) pk_path="$OPTARG" ;;
        h) 
            echo "Usage: $0 -i <infra-gitops path> -c <code-task path> -k <private key path>"
            exit 0
            ;;
        \?) 
            echo "Invalid option: -$OPTARG" >&2
            echo "Usage: $0 -i <infra-gitops path> -c <code-task path> -k <private key path>" >&2
            exit 1 
            ;;
    esac
done

# ssh key validity check
if [[ -n "$pk_path" ]]; then
    if ! ssh-keygen -l -f "$pk_path" >/dev/null 2>&1; then
        echo "Invalid ssh key."
        exit 1
    fi
fi

# Exist check
if [ ! -d "$infra_path" ] || [ ! -d "$code_path" ]; then
    echo "Error: Paths are not valid. Aborting..."
    exit 1
fi

# is-git-repo check. Prereq for pre-commit install
# Currently it doesn't account for the helm path
if [ ! -d "$infra_path/.git" ] || [ ! -d "$code_path/.git" ]; then
    echo "👺 Some of the paths are not Git repo. Aborting..." >&2
    exit 1
fi

infra_path=$(realpath "$infra_path")
code_path=$(realpath "$code_path")
pk_path=$(realpath "$pk_path")
pk_basename=$(basename "$pk_path")

# Paths inside the container
infra_workdir="/app/infra-gitops"
code_workdir="/app/code-task"
pk_mount="/root/.ssh/$pk_basename"

# Check for image presence, decide whether or not to build
if ! docker image inspect "$image_name" > /dev/null 2>&1; then
    echo "Image '$image_name' does not exist. Building..."
    docker build -t "$image_name" "$dockerfile_dir" || { echo "Build failed"; exit 1; }
fi

# Check for container presence and then run it... or not
# If some other image is using the container_name, abort
# otherwise... have a good'un
if docker ps -a --format '{{.Names}}' | grep -wq "$container_name"; then
    existing_image=$(docker inspect --format '{{.Config.Image}}' "$container_name")

    if [ "$existing_image" == "$image_name" ]; then
        echo "Container '$container_name' is from the correct image. Removing it for a re-run..."
        docker rm -f "$container_name"
    else
        echo "Container '$container_name' exists but is from other origin: '$existing_image'"
        echo "Aborting sequence to avoid conflict!"
        exit 1
    fi
fi

# Run the container if all else went well
echo "Running container '$container_name'"
docker run -dt --name "$container_name" --rm \
    -v "$code_path":"$code_workdir" \
    -v "$infra_path":"$infra_workdir" \
    -v "$pk_path":"$pk_mount" \
    -v "$pk_path.pub":"$pk_mount.pub" \
    "$image_name" \
    "tail -f /dev/null"

# Setup git to use ssh key
docker exec -it "$container_name" /bin/bash -c "git config --global commit.gpgsign false"

# Pre-commit pre-setup
echo "Resolving dubious ownership on repos..."
git_cmd="git config --global --add safe.directory $infra_workdir && git config --global --add safe.directory $code_workdir"
docker exec -it "$container_name" /bin/bash -c "$git_cmd"

# Pre-commit setup
echo "Setting up pre-commit in repos"
precommit_cmd="cd $infra_workdir && pre-commit install && cd $code_workdir && pre-commit install"
docker exec -it "$container_name" /bin/bash -c "$precommit_cmd"

# Alias for fetching Kubectl config for later use
echo "Adding aliases..."
cluster_name="my-gke"
region_name="asia-northeast3"
project_name="my-code-vocab"
get_conf="gcloud container clusters get-credentials $cluster_name --region $region_name --project $project_name"
alias="alias kinit='$get_conf'"
alias_cmd="echo \"$alias\" >> /etc/bash.bashrc"
docker exec --user root -it "$container_name" /bin/bash -c "$alias_cmd"

# Open interactive session
echo "Opening an interactive session..."
docker exec -it "$container_name" /bin/bash
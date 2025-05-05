#!/bin/bash

image_name="dequila-image"
container_name="dequila-cont"
dockerfile_dir="."

# Projects paths arguments
infra_path=$(realpath "${1:-$(pwd)}")
code_path=$(realpath "${2:-$(pwd)}")
helm_path=$(realpath "${3:-$(pwd)}")

if [ ! -d "$infra_path" ] || [ ! -d "$helm_path" ] || [ ! -d "$code_path" ]; then
    echo "Error: Paths are not valid."
    exit 1
fi

infra_workdir="/app/infra-gitops"
helm_workdir="/app/helm"
code_workdir="/app/code-task"

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
docker run -it --name "$container_name" --rm -v "$code_path":"$code_workdir" -v "$infra_path":"$infra_workdir" -v "$helm_path":"$helm_workdir" "$image_name" /bin/bash
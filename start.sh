#!/usr/bin/env bash

# Init
org_name="dequila"
image_name="$org_name-image"
container_name="$org_name-cont"
dockerfile_dir="."
user=$(whoami)
uid=$(id -u)
gid=$(id -g)
CURR_DIR=$(pwd)
org_path=""
pk_path=""
PROJECT_ID=$(grep '"project_id"' key.json | head -1 | sed -E 's/.*: "(.*)",?/\1/')
# DO NOT USE SHIFT HERE! ❌

# Dashed args parsing
while getopts "o:k:h:" opt; do
    case $opt in
        o) org_path="$OPTARG" ;;
        k) pk_path="$OPTARG" ;;
        h) 
            echo "Usage: $0 -o <organization path> -k <private key path>"
            exit 0
            ;;
        \?) 
            echo "Invalid option: -$OPTARG" >&2
            echo "Usage: $0 -o <organization path> -k <private key path>" >&2
            exit 1 
            ;;
    esac
done

# Required arguments
if [ -z "$org_path" ]; then
    echo -e "\033[38;5;160m-o [organization/dir/path] is required\033[0m"
    exit 1
fi

# No key path -> use any key
if [ -z "$pk_path" ]; then
    pk_path=$(find "$HOME/.ssh" -type f -name "id*" ! -name "*.pub" -print -quit)
    echo "No key was provided. Using key $pk_path"
fi

# ssh key validity check
if [[ -n "$pk_path" ]]; then
    if ! ssh-keygen -l -f "$pk_path" >/dev/null 2>&1; then
        echo "Invalid ssh key."
        exit 1
    fi
fi

# Exist check
if [[ ! -d "$org_path" ]]; then
    echo "Error: Organization path  not valid. Aborting..."
    exit 1
fi

# Valid org check
gfound=$(find "$org_path"/* -maxdepth 0 -type d -exec test -d "{}/.git" \; -print)
if [ -z "$gfound" ]; then
    echo "❌ No Git repos found under $org_path"
    exit 1
fi 


org_path=$(realpath "$org_path")
pk_path=$(realpath "$pk_path")
pk_basename=$(basename "$pk_path")

# Paths inside the container
org_workdir="/app/$org_name"
pk_mount="/home/$user/.ssh/$pk_basename"

# Check for image presence, decide whether or not to build
if ! docker image inspect "$image_name" > /dev/null 2>&1; then
    echo "Image '$image_name' does not exist. Building..."
    docker build -t "$image_name" \
    --build-arg USER="$user" \
    --build-arg USER_UID="$uid" \
    --build-arg USER_GID="$gid" \
    "$dockerfile_dir" \
    || { echo "Build failed"; exit 1; }
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
    -v "$org_path":"$org_workdir" \
    -v "$pk_path":"$pk_mount" \
    -v "$pk_path.pub":"$pk_mount.pub" \
    "$image_name" \
    "tail -f /dev/null"

# Setup git to use ssh key
docker exec -it --user "$user" "$container_name" /bin/bash -c "git config --global commit.gpgsign false"

# Pre-commit pre-setup and setup
echo "Resolving dubious ownership on repos..."
for dir in "$org_path"/*/; do
    if [ -d "${dir}.git" ]; then
        target="$org_workdir/$(basename "$dir")"
        if [ -f "${target}/.git/hooks/pre-commit" ]; then
            git_cmd="git config --global --add safe.directory $target"
            precommit_own="&& chown $user:$user ${target}/.git/hooks/pre-commit"
            docker exec -it --user root "$container_name" /bin/bash -c "$git_cmd $precommit_own"
            precommit_cmd="cd ${target} && pre-commit install"
            docker exec -it --user root "$container_name" /bin/bash -c "$precommit_cmd"
        fi
        if [ -f "${target}/.ruff_cache" ]; then
            own_cmd="chown -R $user:$user ${target}/.ruff_cache"
            mod_cmd="chmod -R 770 ${target}/.ruff_cache"
            docker exec -it --user root "$container_name" /bin/bash -c "$own_cmd && $mod_cmd"
        fi
    fi
done

# Inject git identity to /home/user/.gitconfig (inside the container)
gname=$(git config --global user.name || id -un)
gemail=$(git config --global user.email)
gident_cmd="git config --global user.name $gname && git config --global user.email $gemail"
docker exec -it --user "$user" "$container_name" /bin/bash -c "$gident_cmd"

# Alias for fetching Kubectl config for later use
echo "Adding aliases..."
cluster_name="dequila-gke-cluster"
region_name="asia-northeast3"
get_conf="gcloud container clusters get-credentials $cluster_name --region $region_name --project $PROJECT_ID"
alias="alias kinit='$get_conf'"
alias_cmd="echo \"$alias\" >> /etc/bash.bashrc"
docker exec --user root -it "$container_name" /bin/bash -c "$alias_cmd"

# Open interactive session
echo "Opening an interactive session..."
docker exec --user "$user" -it "$container_name" /bin/bash

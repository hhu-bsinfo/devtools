#!/bin/bash

# Create a configuration file with the following contents in the comments and adjust the parameters
#
# NAME="Octo Cat"
# EMAIL="octocat@github.com"
# GITHUB_USER="octocat"
# REMOTE_ORIGIN="origin"
# REMOTE_SHARED="bsinfo"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Abort on any errors
set -e

source ${SCRIPT_DIR}/hhubs-git.conf

readonly GITHUB_SHARED="git@github.com:hhu-bsinfo"
readonly GITHUB_ORIGIN="git@github.com:$GITHUB_USER"

readonly REPOSITORIES=("cdepl"  "dxbuild" "dxdevtools" "dxmem" "dxmon" "dxnet" "dxram" "dxutils" "ibdxnet")

clone_and_setup_repository()
{
    local repo_name=$1

    if [ -d "$repo_name" ]; then
        echo "Skipping existing repo $repo_name"
        return
    fi

    git clone $GITHUB_SHARED/$repo_name
    cd $repo_name
    git config user.name "$NAME"
    git config user.email "$EMAIL"
    git remote rename origin $REMOTE_SHARED
    git remote add $REMOTE_ORIGIN $GITHUB_ORIGIN/$repo_name
    git fetch $REMOTE_ORIGIN
    git checkout -b development $REMOTE_SHARED/development
    cd ..
}

checkout_branch_repository()
{
    local repo_name=$1
    local branch=$2

    cd $repo_name
    git checkout $branch
    cd ..
}

fetch_and_rebase_hhubs()
{
    local repo_name=$1
    local remote_name=$2
    local branch_name=$3

    cd $repo_name
    git fetch $remote_name

    set +e
    # Check if branch exists
    git rev-parse --verify $branch_name > /dev/null

    if [ "$?" = "0" ]; then
        set -e
        echo "$branch_name branch..."
        git checkout $branch_name
        git rebase $remote_name/$branch_name
    fi

    set -e
    
    cd ..
}

push_to_remote()
{
    local repo_name=$1
    local remote_name=$2
    local branch_name=$3

    cd $repo_name

    set +e
    # Check if branch exists
    git rev-parse --verify $branch_name > /dev/null

    if [ "$?" = "0" ]; then
        set -e
        echo "$branch_name branch..."
        git checkout $branch_name
        git push $remote_name HEAD:$branch_name
    fi

    set -e

    cd ..
}

if [ ! "$1" ]; then
    echo "Git wrapper script to easily batch clone, update or checkout repositories for development"
    echo "Available commands: clone, pull, checkout, push"
    exit -1
fi

case $1 in
    clone)
        for repo in "${REPOSITORIES[@]}"; do
            echo ">>> Cloning $repo..."
            clone_and_setup_repository $repo
        done

        ;;
    
    checkout)
        if [ ! "$2" ]; then
            echo "Specify branch name to switch to"
            exit -1
        fi

        for repo in "${REPOSITORIES[@]}"; do
            echo ">>> Branch switch $repo..."
            checkout_branch_repository $repo $2
        done

        ;;

    pull)
        if [ ! "$2" ]; then
            echo "Specify the remote to pull from"
            exit -1
        fi

        for repo in "${REPOSITORIES[@]}"; do
            echo ">>> Pull $repo from $2..."
            fetch_and_rebase_hhubs $repo $2 master
            fetch_and_rebase_hhubs $repo $2 development
        done
        
        ;;

    push)
        if [ ! "$2" ]; then
            echo "Specify the remote to push to"
            exit -1
        fi

        for repo in "${REPOSITORIES[@]}"; do
            echo ">>> Pushing $repo to $2..."
            push_to_remote $repo $2 master
            push_to_remote $repo $2 development
        done
        
        ;;  

    *)
        echo "Invalid command"
        ;;
esac

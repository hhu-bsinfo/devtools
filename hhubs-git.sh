#!/bin/bash

####################
# TWEAK ME
readonly NAME="Octo Cat"
readonly EMAIL="octocat@github.com"
readonly GITHUB_USER="octocat"

readonly REMOTE_ORIGIN="origin"
readonly REMOTE_SHARED="bsinfo"
# TWEAK ME
####################

readonly GITHUB_SHARED="git@github.com:hhu-bsinfo"
readonly GITHUB_ORIGIN="git@github.com:$GITHUB_USER"

readonly REPOSITORIES=("cdepl" "dxapp-helloworld" "dxbuild" "dxdevtools" "dxmon" "dxnet" "dxram" "dxterm" "dxutils" "ibdxnet")

clone_and_setup_repository()
{
    local repo_name=$1

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

    cd $repo_name
    git fetch $REMOTE_SHARED
    git checkout master
    git rebase $REMOTE_ORIGIN/master
    git checkout development
    git rebase $REMOTE_ORIGIN/development
    cd ..
}

if [ ! "$1" ]; then
    echo "Git wrapper script to easily batch clone, update or checkout repositories for development"
    echo "Available commands: clone, update, checkout"
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

    update)
        for repo in "${REPOSITORIES[@]}"; do
            echo ">>> Updating $repo..."
            fetch_and_rebase_hhubs $repo
        done
        
        ;;

    *)
        echo "Invalid command"
        ;;
esac

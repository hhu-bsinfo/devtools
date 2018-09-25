#!/bin/bash

# Create a configuration file with the following contents in the comments and adjust the parameters
#
# LOCAL_DXRAM_WORKSPACE="/home/user/workspace"
# LOCAL_DIR="/home/user"
# HHUBS_USER="user"
# HHUBS_HOST="sollipulli"
# HHUBS_DIR="/home/user"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Abort on any errors
set -e

source ${SCRIPT_DIR}/dxram-dev.conf

LOCAL_DXRAM_DIR="${LOCAL_DXRAM_WORKSPACE}/dxram"
LOCAL_DXNET_DIR="${LOCAL_DXRAM_WORKSPACE}/dxnet"
LOCAL_IBDXNET_DIR="${LOCAL_DXRAM_WORKSPACE}/ibdxnet"
LOCAL_DXMEM_DIR="${LOCAL_DXRAM_WORKSPACE}/dxmem"
LOCAL_DXRAM_YCSB="${LOCAL_DXRAM_WORKSPACE}/ycsb-dxram"
LOCAL_DXAPPS_DIR="${LOCAL_DXRAM_WORKSPACE}/dxapps"
LOCAL_CDEPL_DIR="${LOCAL_DXRAM_WORKSPACE}/cdepl"

DXRAM_DIST_DIR="${LOCAL_DXRAM_DIR}/build/dist/dxram"
DXRAM_DIST_ZIP="${DXRAM_DIST_DIR}.zip"

compile_dxapps()
{
    local type="$1"
    local clean="$2"

    if [ ! -e "$LOCAL_DXAPPS_DIR" ]; then
        echo "ERROR: Cannot find project folder: $LOCAL_DXAPPS_DIR"
    fi

    cd $LOCAL_DXAPPS_DIR

    if [ "$clean" = "1" ]; then
        ./gradlew clean
    fi
   
    if [ "$type" ]; then
        ./build.sh $type
    else
        ./build.sh
    fi
}

compile_ycsb()
{
    local type="$1"
    local clean="$2"

    # requires compiled dxram binaries (make sure to compile dxram first)
    echo "Compile dxram..."    
    compile_dxram $type $clean

    cd $LOCAL_DXRAM_YCSB

    if [ "$clean" = "1" ]; then
        mvn clean
    fi
    
    rm -r dxram/lib
    cp -r "${DXRAM_DIST_DIR}/lib" dxram/lib
    
    mvn install package -DskipTests
}

compile_dxmem()
{
    local type="$1"
    local clean="$2"

    if [ ! -e "$LOCAL_DXMEM_DIR" ]; then
        echo "ERROR: Cannot find project folder: $LOCAL_DXMEM_DIR"
    fi

    cd $LOCAL_DXMEM_DIR

    if [ "$clean" = "1" ]; then
        ./gradlew clean
    fi
   
    if [ "$type" ]; then
        ./build.sh $type
    else
        ./build.sh
    fi
}

compile_ibdxnet()
{
    local type="$1"
    local clean="$2"
    local remote="$3"
    local node="$4"

    if [ ! "$remote" ]; then
        cd $LOCAL_IBDXNET_DIR

        if [ "$clean" = "1" ]; then
            rm -rf build/
        fi
        
        ./build.sh $type
    elif [ "$remote" = "hhubs" ]; then
        if [ ! "$node" ]; then
            echo "Please specify node to compile on (doesn't work on sollipulli)"
            exit 1
        fi

        echo "Remote compiling hhubs on node $node..."
        cd $LOCAL_IBDXNET_DIR

        if [ "$clean" = "1" ]; then
            ssh ${HHUBS_USER}@${node} "rm -r ${HHUBS_DIR}/ibdxnet"
        fi

        ssh ${HHUBS_USER}@${node} "mkdir -p ${HHUBS_DIR}/ibdxnet"
        rsync -avz --delete cmake/ ${HHUBS_USER}@${node}:${HHUBS_DIR}/ibdxnet/cmake/
        rsync -avz --delete libs/ ${HHUBS_USER}@${node}:${HHUBS_DIR}/ibdxnet/libs/
        rsync -avz --delete src/ ${HHUBS_USER}@${node}:${HHUBS_DIR}/ibdxnet/src/
        rsync -avz --delete build.sh ${HHUBS_USER}@${node}:${HHUBS_DIR}/ibdxnet/build.sh
        rsync -avz --delete CMakeLists.txt ${HHUBS_USER}@${node}:${HHUBS_DIR}/ibdxnet/CMakeLists.txt

        ssh ${HHUBS_USER}@${node} "cd ${HHUBS_DIR}/ibdxnet && ./build.sh $type"
    else
        echo "Invalid remote $remote"
        exit 1
    fi
}

compile_dxnet()
{
    local type="$1"
    local clean="$2"

    if [ ! -e "$LOCAL_DXNET_DIR" ]; then
        echo "ERROR: Cannot find project folder: $LOCAL_DXNET_DIR"
    fi

    cd $LOCAL_DXNET_DIR
   
    if [ "$clean" = "1" ]; then
        ./gradlew clean
    fi

    if [ "$type" ]; then
        ./build.sh $type
    else
        ./build.sh
    fi
}

compile_dxram()
{
    local type="$1"
    local clean="$2"

    if [ ! -e "$LOCAL_DXRAM_DIR" ]; then
        echo "ERROR: Cannot find project folder: $LOCAL_DXRAM_DIR"
    fi

    cd $LOCAL_DXRAM_DIR

    if [ "$clean" = "1" ]; then
        ./gradlew clean
    fi
   
    if [ "$type" ]; then
        ./build.sh $type
    else
        ./build.sh
    fi
}

copy_dxapps()
{
    local remote="$1"
    local clean="$2"

    if [ "$remote" = "hhubs" ]; then
        cd $LOCAL_DXAPPS_DIR

        if [ "$clean" ]; then
            ssh ${HHUBS_USER}@${HHUBS_HOST} "rm ${HHUBS_DIR}/dxram/dxapps/*"
        fi

        scp ${LOCAL_DXAPPS_DIR}/dxa-chunkbench/build/libs/dxa-chunkbench.jar ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/dxapp/
        scp ${LOCAL_DXAPPS_DIR}/dxa-helloworld/build/libs/dxa-helloworld.jar ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/dxapp/
        scp ${LOCAL_DXAPPS_DIR}/dxa-migration/build/libs/dxa-migration.jar ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/dxapp/
        scp ${LOCAL_DXAPPS_DIR}/dxa-terminal/server/build/libs/dxa-terminal.jar ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/dxapp/
    else
        echo "Invalid remote: $remote"
        exit 1
    fi
}

copy_ycsb()
{
    echo "TODO"
    exit 1
}

copy_dxmem()
{
    echo "TODO"
    exit 1
}

copy_dxnet()
{
    echo "TODO"
    exit 1
}

copy_dxram()
{
    local remote="$1"
    local clean="$2"

    if [ "$remote" = "hhubs" ]; then
        cd $LOCAL_DXRAM_DIR

        if [ "$clean" ]; then
            ssh ${HHUBS_USER}@${HHUBS_HOST} "rm -r ${HHUBS_DIR}/dxram"
        fi

        rsync -avz ${DXRAM_DIST_DIR}/ ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/

        # check if ibdxnet is available and copy
        if [ "$(ssh ${HHUBS_USER}@${HHUBS_HOST} "[ -d ${HHUBS_DIR}/ibdxnet/build ] && echo \"1\"")" ]; then
            echo "Found compiled ibdxnet lib, copying to dxram jni folder..."
            ssh ${HHUBS_USER}@${HHUBS_HOST} "cp ${HHUBS_DIR}/ibdxnet/build/lib/libMsgrcJNIBinding.so ${HHUBS_DIR}/dxram/jni/"
        fi
    else
        echo "Invalid remote: $remote"
        exit 1
    fi
}

depl_dxram()
{
    local remote="$1"
    local mode="$2"  
    local args=${@:3}

    cd $LOCAL_CDEPL_DIR

    case $mode in
        run)
            ./cdepl.sh scripts/dxram.cdepl $args
            ;;

        kill)
            ./cdepl.sh scripts/dxram_killall.cdepl $args
            ;;
        
        *)
            echo "Invalid mode: $mode"
            exit 1
    esac
}

term()
{
    ${LOCAL_DXAPPS_DIR}/dxa-terminal/client/build/dist/client/bin/client ${@:1}
}

depl()
{
    local prog="$1"
    local remote="$2"
    local mode="$3"

    echo "Deploying $prog to $remote..."

    case $prog in
        dxram)
            depl_dxram $remote $mode ${@:4}
            ;;

        *)
            echo "Invalid compile target: all, dxram, dxnet, dxmem, ycsb, dxapps"
            ;;
    esac
}

copy()
{
    local prog="$1"
    local remote="$2"
    local clean="$3"

    echo "Copying $prog to $remote (clean: $clean)..."

    case $prog in
        all)
            copy_dxram $remote $clean ${@:4}
            copy_dxnet $remote $clean ${@:4}
            copy_dxmem $remote $clean ${@:4}
            copy_ycsb $remote $clean ${@:4}
            copy_dxapps $remote $clean ${@:4}
            ;;

        dxram)
            copy_dxram $remote $clean ${@:4}
            ;;

        dxnet)
            copy_dxnet $remote $clean ${@:4}
            ;;

        dxmem)
            copy_dxmem $remote $clean ${@:4}
            ;;

        ycsb)
            copy_ycsb $remote $clean ${@:4}
            ;;

        dxapps)
            copy_dxapps $remote $clean ${@:4}
            ;;

        *)
            echo "Invalid compile target: all, dxram, dxnet, dxmem, ycsb, dxapps"
            ;;
    esac
}

compile()
{
    local prog="$1"
    local type="$2"
    local clean="$3"

    echo "Compiling $prog (type: $type, clean: $clean)..."

    case $prog in
        all)
            compile_dxram $type $clean ${@:4}
            compile_dxnet $type $clean ${@:4}
            compile_ibdxnet $type $clean ${@:4}
            compile_dxmem $type $clean ${@:4}
            compile_ycsb $type $clean ${@:4}
            compile_dxapps $type $clean ${@:4}
            ;;

        dxram)
            compile_dxram $type $clean ${@:4}
            ;;

        dxnet)
            compile_dxnet $type $clean ${@:4}
            ;;

        ibdxnet)
            compile_ibdxnet $type $clean ${@:4}
            ;;

        dxmem)
            compile_dxmem $type $clean ${@:4}
            ;;

        ycsb)
            compile_ycsb $type $clean ${@:4}
            ;;

        dxapps)
            compile_dxapps $type $clean ${@:4}
            ;;

        *)
            echo "Invalid compile target: all, dxram, dxnet, ibdxnet, dxmem, ycsb, dxapps"
            ;;
    esac
}

if [ "$#" -lt 1 ]; then
    echo "Internal DXRAM development tool for compiling, copying and deploying DXRAM and related projects"
    echo "Available commands: cc (compile), cp (copy compiled output), depl (run deployment)"
    exit -1
fi

cmd="$1"
prog="$2"

case $cmd in
    cc)
        compile $prog ${@:3}
        ;;

    cp)
        copy $prog ${@:3}
        ;;

    depl)
        depl $prog ${@:3}
        ;;

    term)
        term ${@:2}
        ;;

    *)
        echo "Invalid command"
        ;;
esac

#!/bin/bash

# Create a configuration file with the following contents in the comments and adjust the parameters
#
# LOCAL_DXRAM_WORKSPACE="/home/user/workspace"
# LOCAL_DIR="/home/user"
# HHUBS_USER="user"
# HHUBS_HOST="sollipulli"
# HHUBS_DIR="/home/user"
# HILBERT_USER="user"
# HILBERT_DIR="/home/user"

readonly HILBERT_HOST="hpc.rz.uni-duesseldorf.de"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Abort on any errors
set -e

source ${SCRIPT_DIR}/dxram-dev.conf

LOCAL_DXRAM_DIR="${LOCAL_DXRAM_WORKSPACE}/dxram"
LOCAL_DXNET_DIR="${LOCAL_DXRAM_WORKSPACE}/dxnet"
LOCAL_IBDXNET_DIR="${LOCAL_DXRAM_WORKSPACE}/ibdxnet"
LOCAL_DXMEM_DIR="${LOCAL_DXRAM_WORKSPACE}/dxmem"
LOCAL_DXRAM_YCSB="${LOCAL_DXRAM_WORKSPACE}/YCSB"
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
        ./build.sh clean
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
    
    rm -rf dxram/lib
    cp -r "${DXRAM_DIST_DIR}/lib" dxram/lib
    
    mvn -pl com.yahoo.ycsb:dxram-binding -am clean package -DskipTests
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
        ./build.sh clean
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
            echo "Please specify the node of hhubs (e.g. node65) to compile on (doesn't work on sollipulli)"
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
    elif [ "$remote" = "hilbert" ]; then
        if [ ! "$node" ]; then
            echo "Please specify the target architecture: ivybridge or skylake"
            exit 1
        fi

        echo "Remote compiling hilbert for target arch $node..."
        cd $LOCAL_IBDXNET_DIR

        if [ "$clean" = "1" ]; then
            ssh ${HILBERT_USER}@${HILBERT_HOST} "rm -r ${HILBERT_DIR}/ibdxnet"
        fi

        ssh ${HILBERT_USER}@${HILBERT_HOST} "mkdir -p ${HILBERT_DIR}/ibdxnet"
        rsync -avz --delete cmake/ ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/ibdxnet/cmake/
        rsync -avz --delete libs/ ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/ibdxnet/libs/
        rsync -avz --delete src/ ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/ibdxnet/src/
        rsync -avz --delete build.sh ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/ibdxnet/build.sh
        rsync -avz --delete CMakeLists.txt ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/ibdxnet/CMakeLists.txt

        # create job script
        local pbs_job_string="
#!/bin/bash

# job attributes
#PBS -l select=1:ncpus=4:mem=4GB:arch=${node}
#PBS -l place=scatter
#PBS -l walltime=00:15:00
#PBS -r n
#PBS -N ibdxnet_cc
#PBS -A dxram
#PBS -e /home/${HILBERT_USER}/ibdxnet/compile.stderr
#PBS -o /home/${HILBERT_USER}/ibdxnet/compile.stdout

echo \"\$PBS_NODEFILE\"

readonly SCRIPT_DIR=\"\$( cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd )\"

module load gcc/6.1.0
module load cmake/3.5.1
module load Java/1.8.0

cd ~/ibdxnet

# Add further include paths if not already inserted
# Required on hilbert environment with module system
if [ ! \"\$(grep \"/software/java\" cmake/MsgrcJNIBinding/CMakeLists.txt)\" ]; then
        sed -i -e 's/include_directories(\${IBNET_SRC_DIR})/include_directories(\${IBNET_SRC_DIR\})\ninclude_directories(\/software\/java\/1\.8\.0_25\/include)\ninclude_directories(\/software\/java\/1.8.0_25\/include\/linux)/g' cmake/MsgrcJNIBinding/CMakeLists.txt
fi

./build.sh
"

        echo "$pbs_job_string" > /tmp/ibdxnet_cc.job
        scp /tmp/ibdxnet_cc.job ${HILBERT_USER}@${HILBERT_HOST}:/home/${HILBERT_USER}/ibdxnet/
        ssh ${HILBERT_USER}@${HILBERT_HOST} "rm -f /home/${HILBERT_USER}/ibdxnet/compile.std*"
        ssh ${HILBERT_USER}@${HILBERT_HOST} "qsub -q BenchMarking /home/${HILBERT_USER}/ibdxnet/ibdxnet_cc.job"

        echo "Waiting for compile job to finish..."

        while true; do
            if [ $(ssh ${HILBERT_USER}@${HILBERT_HOST} "[ -f /home/${HILBERT_USER}/ibdxnet/compile.stdout ] && echo 1" = "1") ]; then
                printf "\nFinished\n"
                break
            fi

            sleep 1
            printf "."
        done
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
        ./build.sh clean
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
        ./build.sh clean
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

        rsync -avz ${LOCAL_DXAPPS_DIR}/dxa-chunkbench/build/libs/dxa-chunkbench.jar ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/dxapp/
        rsync -avz ${LOCAL_DXAPPS_DIR}/dxa-helloworld/build/libs/dxa-helloworld.jar ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/dxapp/
        # rsync -avz ${LOCAL_DXAPPS_DIR}/dxa-migration/build/libs/dxa-migration.jar ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/dxapp/
        rsync -avz ${LOCAL_DXAPPS_DIR}/dxa-terminal/server/build/libs/dxa-terminal.jar ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxram/dxapp/
    elif [ "$remote" = "hilbert" ]; then
        cd $LOCAL_DXAPPS_DIR

        if [ "$clean" ]; then
            ssh ${HILBERT_USER}@${HILBERT_HOST} "rm ${HILBERT_DIR}/dxram/dxapps/*"
        fi

        rsync -avz ${LOCAL_DXAPPS_DIR}/dxa-chunkbench/build/libs/dxa-chunkbench.jar ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/dxram/dxapp/
        rsync -avz ${LOCAL_DXAPPS_DIR}/dxa-helloworld/build/libs/dxa-helloworld.jar ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/dxram/dxapp/
        # rsync -avz ${LOCAL_DXAPPS_DIR}/dxa-migration/build/libs/dxa-migration.jar ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/dxram/dxapp/
        rsync -avz ${LOCAL_DXAPPS_DIR}/dxa-terminal/server/build/libs/dxa-terminal.jar ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/dxram/dxapp/
    else
        echo "Invalid remote: $remote"
        exit 1
    fi
}

copy_ycsb()
{
    local package_filename="ycsb-dxram-binding-0.16.0-SNAPSHOT"

    local remote="$1"
    local clean="$2"

    if [ "$remote" = "hhubs" ]; then
        if [ "$clean" ]; then
            ssh ${HHUBS_USER}@${HHUBS_HOST} "rm -r ${HHUBS_DIR}/ycsb-dxram"
        fi

        # ycsb build output
        cd ${LOCAL_DXRAM_YCSB}/dxram/target/
        tar -xzvf ${package_filename}.tar.gz
        rsync -avz ${LOCAL_DXRAM_YCSB}/dxram/target/${package_filename}/ ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/ycsb-dxram/
        rm -r ${package_filename}

        # copy dxram to ycsb-dxram folder
        rsync -avz ${DXRAM_DIST_DIR}/ ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/ycsb-dxram/

        # check if ibdxnet is available and copy
        if [ "$(ssh ${HHUBS_USER}@${HHUBS_HOST} "[ -d ${HHUBS_DIR}/ibdxnet/build ] && echo \"1\"")" ]; then
            echo "Found compiled ibdxnet lib, copying to dxram jni folder..."
            ssh ${HHUBS_USER}@${HHUBS_HOST} "cp ${HHUBS_DIR}/ibdxnet/build/lib/libMsgrcJNIBinding.so ${HHUBS_DIR}/ycsb-dxram/jni/"
        fi
    elif [ "$remote" = "hilbert" ]; then
        if [ "$clean" ]; then
            ssh ${HILBERT_USER}@${HILBERT_HOST} "rm -r ${HILBERT_DIR}/ycsb-dxram"
        fi

        # ycsb build output
        cd ${LOCAL_DXRAM_YCSB}/dxram/target/
        tar -xzvf ${package_filename}.tar.gz
        rsync -avz ${LOCAL_DXRAM_YCSB}/dxram/target/${package_filename}/ ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/ycsb-dxram/
        rm -r ${package_filename}

        # copy dxram to ycsb-dxram folder
        rsync -avz ${DXRAM_DIST_DIR}/ ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/ycsb-dxram/

        # check if ibdxnet is available and copy
        if [ "$(ssh ${HILBERT_USER}@${HILBERT_HOST} "[ -d ${HILBERT_DIR}/ibdxnet/build ] && echo \"1\"")" ]; then
            echo "Found compiled ibdxnet lib, copying to dxram jni folder..."
            ssh ${HILBERT_USER}@${HILBERT_HOST} "cp ${HILBERT_DIR}/ibdxnet/build/lib/libMsgrcJNIBinding.so ${HILBERT_DIR}/ycsb-dxram/jni/"
        fi
    else
        echo "Invalid remote: $remote"
        exit 1
    fi
}

copy_dxmem()
{
    echo "TODO"
    exit 1
}

copy_dxnet()
{
    local remote="$1"
    local clean="$2"

    if [ "$remote" = "hhubs" ]; then
        cd $LOCAL_DXNET_DIR

        if [ "$clean" ]; then
            ssh ${HHUBS_USER}@${HHUBS_HOST} "rm -r ${HHUBS_DIR}/dxnet"
        fi

        rsync -avz build/dist/dxnet/ ${HHUBS_USER}@${HHUBS_HOST}:${HHUBS_DIR}/dxnet/

        # check if ibdxnet is available and copy
        if [ "$(ssh ${HHUBS_USER}@${HHUBS_HOST} "[ -d ${HHUBS_DIR}/ibdxnet/build ] && echo \"1\"")" ]; then
            echo "Found compiled ibdxnet lib, copying to dxram jni folder..."
            ssh ${HHUBS_USER}@${HHUBS_HOST} "cp ${HHUBS_DIR}/ibdxnet/build/lib/libMsgrcJNIBinding.so ${HHUBS_DIR}/dxnet/jni/"
        fi
    elif [ "$remote" = "hilbert" ]; then
        cd $LOCAL_DXNET_DIR

        if [ "$clean" ]; then
            ssh ${HILBERT_USER}@${HILBERT_HOST} "rm -r ${HILBERT_DIR}/dxnet"
        fi

        rsync -avz build/dist/dxnet/ ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/dxnet/

        # check if ibdxnet is available and copy
        if [ "$(ssh ${HILBERT_USER}@${HILBERT_HOST} "[ -d ${HILBERT_DIR}/ibdxnet/build ] && echo \"1\"")" ]; then
            echo "Found compiled ibdxnet lib, copying to dxram jni folder..."
            ssh ${HILBERT_USER}@${HILBERT_HOST} "cp ${HILBERT_DIR}/ibdxnet/build/lib/libMsgrcJNIBinding.so ${HILBERT_DIR}/dxnet/jni/"
        fi
    else
        echo "Invalid remote: $remote"
        exit 1
    fi
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
    elif [ "$remote" = "hilbert" ]; then
        cd $LOCAL_DXRAM_DIR

        if [ "$clean" ]; then
            ssh ${HILBERT_USER}@${HILBERT_HOST} "rm -r ${HILBERT_DIR}/dxram"
        fi

        rsync -avz ${DXRAM_DIST_DIR}/ ${HILBERT_USER}@${HILBERT_HOST}:${HILBERT_DIR}/dxram/

        # check if ibdxnet is available and copy
        if [ "$(ssh ${HILBERT_USER}@${HILBERT_HOST} "[ -d ${HILBERT_DIR}/ibdxnet/build ] && echo \"1\"")" ]; then
            echo "Found compiled ibdxnet lib, copying to dxram jni folder..."
            ssh ${HILBERT_USER}@${HILBERT_HOST} "cp ${HILBERT_DIR}/ibdxnet/build/lib/libMsgrcJNIBinding.so ${HILBERT_DIR}/dxram/jni/"
        fi
    else
        echo "Invalid remote: $remote"
        exit 1
    fi
}

depl_dxram()
{
    local mode="$1"  
    local args=${@:2}

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

depl_ycsb()
{
    local mode="$1"  
    local args=${@:2}

    cd $LOCAL_CDEPL_DIR

    case $mode in
        run)
            ./cdepl.sh scripts/dxram_ycsb.cdepl $args
            ;;

        kill)
            ./cdepl.sh scripts/dxram_killall.cdepl $args
            ;;
        
        *)
            echo "Invalid mode: $mode"
            exit 1
    esac
}

depl_dxnet()
{
    local mode="$1"  
    local args=${@:2}

    cd $LOCAL_CDEPL_DIR

    case $mode in
        run)
            ./cdepl.sh scripts/dxnet_bench.cdepl $args
            ;;

        kill)
            ./cdepl.sh scripts/dxnet_killall.cdepl $args
            ;;
        
        *)
            echo "Invalid mode: $mode"
            exit 1
    esac
}

term()
{    
    local remote="$1"
    local port="$2"
    local cluster="$3"
    
    case $cluster in
        hhubs)
            echo "Port forwarding over sollipulli active"
            ssh -L 9998:localhost:9998 sollipulli ssh -L 9998:localhost:$port -N $remote &
            local tunnel_pid=$!

            ${LOCAL_DXAPPS_DIR}/dxa-terminal/client/build/dist/client/bin/client localhost 9998
            kill -9 $tunnel_pid
            ;;
        *)
            ${LOCAL_DXAPPS_DIR}/dxa-terminal/client/build/dist/client/bin/client $remote $port
    esac
}

depl()
{
    local prog="$1"

    echo "Deploying $prog..."

    case $prog in
        dxram)
            depl_dxram ${@:2}
            ;;

        ycsb)
            depl_ycsb ${@:2}
            ;;

        dxnet)
            depl_dxnet ${@:2}
            ;;

        *)
            echo "Invalid deply target: all, dxram, dxnet, dxmem, ycsb, dxapps"
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
            echo "Invalid copy target: all, dxram, dxnet, dxmem, ycsb, dxapps"
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

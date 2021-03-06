#!/usr/bin/env bash
#Add short help
#Add rest of usage
# ping slack that all nodes are up and running.

#Variables used in script cannot be overridden.
DCE_NAME=$(basename "$0")
DCE_INSTALLED=$(which ${DCE_NAME})
VERBOSE_MODE="false"

SHORT_FLAGS="M:m:C:c:v:p:H:u:n:b:s:DqhVfdN:hi-:T"
LONG_OPTS="[help][delete][delete-only][cattle-version]:[python-agent-version]:[name]:[ngrok][ngrok-url][ngrok-subdomain]:[do][digitalocean]:[validation-tests][validation-tests-only]"

DCE_COMMAND="show_usage"

#Variables used in script. Can be overridden.
: ${DCE_USAGE_FILE:="/tmp/${DCE_NAME}-usage.txt"}
: ${DCE_DOCKER_MACHINE_DRIVER:=virtualbox}
: ${DCE_MASTER_MEM=2048}
: ${DCE_SLAVE_MEM=1024}
: ${DCE_MASTER_CORES=4}
: ${DCE_SLAVE_CORES=2}
: ${DCE_CLUSTER_NAME=$(whoami)}
: ${DCE_RUN="false"}
: ${DCE_SKIP_CHECK="false"}
: ${DCE_SLAVES=1}
: ${DCE_USE_NGROK:="false"}
: ${DCE_USE_BUILD_MASTER:=false}

DCE_SOURCE=${BASH_SOURCE[0]}
if [[ -L "${DCE_SOURCE}" ]]
then
source $(dirname $(readlink ${DCE_SOURCE}))/getopts/long_args
else
source $(dirname ${DCE_SOURCE})/getopts/long_args
fi

show_usage()
{
    cat 1>&2 <<EOF > ${DCE_USAGE_FILE}

${DCE_NAME} Usage:

    -M - Memory for master node default:${DCE_MASTER_MEM}
        \$DCE_MASTER_MEM

    -m - Memory for slave nodes default:${DCE_SLAVE_MEM}
        Needs to be im MB ex: -m ${DCE_SLAVE_MEM}
        \$DCE_SLAVE_MEM

    -C Number of cores to use for the master node (If drive supports this.)
        Needs to be a number ex: -C ${DCE_MASTER_MEM}
        \$DCE_MASTER_CORES

    -c Number of cores to use for the slave nodes (If drive supports this.)
        Needs to be a number ex: -c ${DCE_SLAVE_CORES}
        \$DCE_SLAVE_CORES

    -v | --cattle-version Specify cattle version in format {githubUser}/{branch/tag/commitSha}
        ex:
            ${DCE_NAME} -v rancher/v0.106.0
            ${DCE_NAME} -v rancher/56744ac585f5e0aa39ef7568a08049d305cdea05
            ${DCE_NAME} -v rancher/master

    -p | --python-agent-version Similar to -v but for Python agent version.
        ex:
            ${DCE_NAME} -p rancher/v0.59.0
            ${DCE_NAME} -p rancher/304646088882dee48f34b330a0182bfe96cec4fd
            ${DCE_NAME} -p rancher/master

    -H Similar to -v but for Host api version.

    -u Similar to -v but for Ui version.

    -n Similar to -v but for Node agent version.

    -b Similar to -v but for build tools version.

    -N Name of the cluster
        ex: ${DCE_NAME} -N rancher-test-cluster
        Master has -master appended and Nodes/slaves have -slave appended.
        Default cluster name is grabbed from whoami
        \$DCE_CLUSTER_NAME

    -h / --help Show this help dialogue.
        ex: ${DCE_NAME} -h

    -V Verbose output. This will display extra text to tell user what is going on while running.
        ex: ${DCE_NAME} -V
        Use flag twice to output messages using random colors per line. And set -x
        ex: ${DCE_NAME} -VV or -V {some other flags} -V

    -f Run with no confirm using all defaults.
        ex: ${DCE_NAME} -f

    -q Run quietly. Meaning set +o
        Still not fully implemented.

    -d | --delete Delete the cluster if it already exists.
        ex: ${DCE_NAME} -d
        \$DCE_DELETE_CLUSTER
    -D | --delete-only Delete the cluster if it already exists. Then exit. (Preempts other flags.)
        When used no other commands will occur. Cluster will just be deleted.
        ex:
            ${DCE_NAME} -D
            ${DCE_NAME} --delete-only
        \$DCE_DELETE_ONLY

    -i Get the master ip of the cluster. Can use with -N if you have multiple clusters.
        ex: ${DCE_NAME} -i
        Might print out 192.168.99.100

    --digitalocean \${DIGITALOCEAN_ACCESS_TOKEN}  Launch vms using Digital Ocean.
        This flag cannot be used with -C -c -M or -M.

    --do Create cluster using Digital Ocean. Assumes \${DIGITALOCEAN_ACCESS_TOKEN} is set in environment.
            This flag cannot be used with -C -c -M or -M.

    -T | --validation-tests Run the validation tests.
        This will use buildmaster to run the validation tests on the cluster in a container on the master.
    --validation-tests-only Run the validation tests on an existing cluster. (Can combine with -N)
        ex: ${DCE_NAME} -N cluster-3 --validation-tests-only


Example usage:

    All defaults: virtual box with 1 master ${DCE_MASTER_CORES} cores ${DCE_MASTER_MEM} mb ram ${DCE_SLAVES} slaves ${DCE_SLAVE_CORES} cores ${DCE_SLAVE_MEM} mb
    ram master for all components from rancher.
        ${DCE_NAME} -f
        or
        ${DCE_NAME} -C ${DCE_MASTER_CORES} -M ${DCE_MASTER_MEM} -c ${DCE_SLAVE_CORES} -m ${DCE_SLAVE_MEM} -s ${DCE_SLAVES}
        or
        ${DCE_NAME} --digitalocean 262415404adaf7be5e5019680014e85e7e70f47d5bceee39668d4130a69a6b74

EOF
if [[ ${DCE_SHORT_HELP} == "true" ]]
then
    cat ${DCE_USAGE_FILE}
else
    cat ${DCE_USAGE_FILE} | less
fi
}

myEcho(){
    if [ "${VERBOSE_MODE}" == "true" ]
    then
        if [ "${USE_RANDOM_COLORS}" == "true" ]
        then
            echo $(tput setaf $(echo $((RANDOM%7+1)))) ${@} $(tput sgr0)
        else
            echo ${@}
        fi
    fi
}

isNum() {
    re='^[0-9]+$'
    if ! [[ ${1} =~ $re ]] ; then
        myEcho "${1} is not a valid number" >&2; show_short_help; exit 3
    fi
}

multiple_drivers() {
    echo Cannot use --digitalocean with -c -C -m or -M.
    show_short_help
    exit 1
}

isValidRepoCommit() {
    local SUPPLIED=${1}
    arrIN=(${SUPPLIED//// })
    [[ -z "${arrIN[0]}" || -z "${arrIN[1]}" ]] && myEcho ${1} is not a proper \{githubUser\}/\{git\|commit/tag/branch\} && exit 4
    EXISTS=$(curl -s -L github.com/${arrIN[0]}/${2}/tree/${arrIN[1]})
    if [[ ${EXISTS} == *"Not Found"* ]]
    then
        echo ${SUPPLIED} not found on github.
        exit 5
    fi
    DCE_USE_BUILD_MASTER="true"
    return 0
}

show_short_help(){
    cat 1>&2 <<EOF
${DCE_NAME} flags:
    -M(Master Memory) [${DCE_MASTER_MEM}]
    -m(slave memory) [${DCE_SLAVE_MEM}]
    -C(Master cores) [${DCE_MASTER_CORES}]
    -c(slave cores) [${DCE_SLAVE_CORES}]
    -v | --cattle-version (cattle version)
    -p | --python-agent-version (python agent version)
    -H(host api version)
    -u(ui version)
    -n(node agent version)
    -N(Cluster name)
    -b(build tools version)
    -h | --help (show Long usage\help)
    -f(force run without other options. EG: use all defaults. Only needed if no other flags defined.)
    -q(silent/ quiet)
    -d | --delete(delete existing cluster if it exists.)
    -D | --delete-only(Only delete existing cluster if it exists.)
    -i Print out master ip of cluster (Can be used in combination with -N)
    --ngrok Run an ngrok container on the master so that rancher can be accessed via public url. (Hides rancher ip.)
    --ngrok-url Get the ngrok url for the cluster.
    --ngrok-subdomain Choose subdomain for ngrok.
    --digitalocean \${DIGITALOCEAN_ACCESS_TOKEN} Create cluster using Digital Ocean vms.
    --do Create cluster using Digital Ocean. Assumes \${DIGITALOCEAN_ACCESS_TOKEN} is set in environment.
    -T | --validation-tests Run validation tests in a container on the master after the cluster launches.
    --validation-tests-only Run validation tests in a container on an existing cluster. Only. (Can combine with -N)

Minimal command to use all defaults:
    ${DCE_NAME} -f
    Using above command will yield $((1 + ${DCE_SLAVES})) machines 1 master ${DCE_SLAVES} slaves where the slaves have ${DCE_SLAVE_MEM}GB ram ${DCE_SLAVE_CORES} cores
    The master will have ${DCE_MASTER_CORES} cores ${DCE_MASTER_MEM} MB of ram  and the will use plain build-master with virtualbox driver.
EOF
}
get_start_build_master_command() {
    if [[ ${DCE_USE_BUILD_MASTER} == "true" ]]
    then
        : ${CATTLE_REPO:="https://github.com/rancherio/cattle.git"}
        : ${CATTLE_WORK_DIR:=cattle}
        : ${CATTLE_COMMIT:=master}

        : ${PYTHON_AGENT_REPO:="https://github.com/rancherio/python-agent.git"}
        : ${PYTHON_AGENT_WORK_DIR:=python-agent}
        : ${PYTHON_AGENT_COMMIT:=master}

        : ${HOST_API_REPO:="https://github.com/rancherio/host-api.git"}
        : ${HOST_API_WORK_DIR:=host-api}
        : ${HOST_API_COMMIT:=master}

        : ${UI_REPO:="https://github.com/rancherio/ui.git"}
        : ${UI_WORK_DIR:=ui}
        : ${UI_COMMIT:=master}

        : ${VALIDATION_TESTS_REPO:="https://github.com/rancherio/validation-tests.git"}
        : ${VALIDATION_TESTS_WORK_DIR:=validation-tests}
        : ${VALIDATION_TESTS_COMMIT:=master}

        : ${NODE_AGENT_REPO:="https://github.com/rancherio/node-agent.git"}
        : ${NODE_AGENT_WORK_DIR:=node-agent}
        : ${NODE_AGENT_COMMIT:=master}

        : ${BUILD_TOOLS_REPO:="https://github.com/rancherio/build-tools.git"}
        : ${BUILD_TOOLS_COMMIT:=master}

        : ${CATTLE_UI_URL:="//releases.rancher.com/ui/latest"}
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e CATTLE_REPO=${CATTLE_REPO} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e CATTLE_WORK_DIR=${CATTLE_WORK_DIR} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e CATTLE_COMMIT=${CATTLE_COMMIT} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e PYTHON_AGENT_REPO=${PYTHON_AGENT_REPO} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e PYTHON_AGENT_WORK_DIR=${PYTHON_AGENT_WORK_DIR} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e PYTHON_AGENT_COMMIT=${PYTHON_AGENT_COMMIT} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e HOST_API_REPO=${HOST_API_REPO} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e HOST_API_WORK_DIR=${HOST_API_WORK_DIR} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e HOST_API_COMMIT=${HOST_API_COMMIT} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e UI_REPO=${UI_REPO} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e UI_WORK_DIR=${UI_WORK_DIR} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e UI_COMMIT=${UI_COMMIT} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e VALIDATION_TESTS_REPO=${VALIDATION_TESTS_REPO} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e VALIDATION_TESTS_WORK_DIR=${VALIDATION_TESTS_WORK_DIR} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e VALIDATION_TESTS_COMMIT=${VALIDATION_TESTS_COMMIT} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e NODE_AGENT_REPO=${NODE_AGENT_REPO} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e NODE_AGENT_WORK_DIR=${NODE_AGENT_WORK_DIR} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e NODE_AGENT_COMMIT=${NODE_AGENT_COMMIT} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e BUILD_TOOLS_REPO=${BUILD_TOOLS_REPO} "
        RUN_CMD_ARGS="${RUN_CMD_ARGS} -e CATTLE_UI_URL=${CATTLE_UI_URL} "
        echo "docker run -d -p 80:8080 ${RUN_CMD_ARGS} --privileged rancher/build-master"
    else
        echo "docker run -d -p 80:8080 rancher/server"
    fi
}

while getopts "${SHORT_FLAGS}" opt; do

    long_args "${!OPTIND}"

    case $opt in
        \?) echo "Invalid option: -$OPTARG" >&2 && show_short_help && exit 1;;
        N | name) DCE_CLUSTER_NAME=$OPTARG ;;
        M)
            [[ ! -z ${_DRIVER_SELECTED} && ${DCE_DOCKER_MACHINE_DRIVER} != "virtualbox" ]] && multiple_drivers
            _DRIVER_SELECTED=true
            isNum $OPTARG && DCE_MASTER_MEM=$OPTARG ;;
        m)
            [[ ! -z ${_DRIVER_SELECTED} && ${DCE_DOCKER_MACHINE_DRIVER} != "virtualbox" ]] && multiple_drivers
            _DRIVER_SELECTED=true
            isNum $OPTARG && DCE_SLAVE_MEM=$OPTARG ;;
        C)
            [[ ! -z ${_DRIVER_SELECTED} && ${DCE_DOCKER_MACHINE_DRIVER} != "virtualbox" ]] && multiple_drivers
            _DRIVER_SELECTED=true
            isNum $OPTARG && DCE_MASTER_CORES=$OPTARG ;;
        c)
            [[ ! -z ${_DRIVER_SELECTED} && ${DCE_DOCKER_MACHINE_DRIVER} != "virtualbox" ]] && multiple_drivers
            _DRIVER_SELECTED=true
            isNum $OPTARG && DCE_SLAVE_CORES=$OPTARG ;;
        v | cattle-version)
            #Set version of cattle. In form of {githubUser}/{commit/tag/branch}
            isValidRepoCommit $OPTARG cattle; arrIN=(${OPTARG//// })
            CATTLE_REPO="https://github.com/${arrIN[0]}/cattle.git"
            CATTLE_COMMIT=${arrIN[1]}
            myEcho Using cattle version $CATTLE_REPO:$CATTLE_COMMIT
            myEcho Github Web view: github.com/${arrIN[0]}/cattle/tree/${arrIN[1]}
            ;;
        p | python-agent-version)
            #Set version of python agent. In form of {githubUser}/{commit/tag/branch}
            isValidRepoCommit $OPTARG python-agent; arrIN=(${OPTARG//// })
            PYTHON_AGENT_REPO="https://github.com/${arrIN[0]}/python-agent.git"
            PYTHON_AGENT_COMMIT=${arrIN[1]}
            myEcho Using python agent version $PYTHON_AGENT_REPO:$PYTHON_AGENT_COMMIT
            myEcho Github Web view: github.com/${arrIN[0]}/python-agent/tree/${arrIN[1]}
            ;;
        H)
            #Set version of hostapi. In form of {githubUser}/{commit/tag/branch}
            isValidRepoCommit $OPTARG host-api; arrIN=(${OPTARG//// })
            HOST_API_REPO="https://github.com/${arrIN[0]}/host-api.git"
            HOST_API_COMMIT=${arrIN[1]}
            myEcho Using cattle version $HOST_API_REPO:$HOST_API_COMMIT
            myEcho Github Web view: github.com/${arrIN[0]}/host-api/tree/${arrIN[1]}
            ;;
        u)
            #Set version of ui. In form of {githubUser}/{commit/tag/branch}
            isValidRepoCommit $OPTARG ui; arrIN=(${OPTARG//// })
            UI_REPO="https://github.com/${arrIN[0]}/ui.git"
            UI_COMMIT=${arrIN[1]}
            myEcho Using cattle version $UI_REPO:$UI_COMMIT
            myEcho Github Web view: github.com/${arrIN[0]}/ui/tree/${arrIN[1]}
            ;;
        n)
            #Set version of node agent. In form of {githubUser}/{commit/tag/branch}
            isValidRepoCommit $OPTARG node-agent; arrIN=(${OPTARG//// })
            NODE_AGENT_REPO="https://github.com/${arrIN[0]}/node-agent.git"
            NODE_AGENT_COMMIT=${arrIN[1]}
            myEcho Using cattle version $NODE_AGENT_REPO:$NODE_AGENT_COMMIT
            myEcho Github Web view: github.com/${arrIN[0]}/node-agent/tree/${arrIN[1]}
            ;;
        b)
            #Set version of build tools. In form of {githubUser}/{commit/tag/branch}
            isValidRepoCommit $OPTARG build-tools; arrIN=(${OPTARG//// })
            BUILD_TOOLS_REPO="https://github.com/${arrIN[0]}/build-tools.git"
            BUILD_TOOLS_COMMIT=${arrIN[1]}
            myEcho Using cattle version $BUILD_TOOLS_REPO:$BUILD_TOOLS_COMMIT
            myEcho Github Web view: github.com/${arrIN[0]}/build-tools/tree/${arrIN[1]}
            ;;
        s)
            isNum $OPTARG
            DCE_SLAVES=$OPTARG
            ;;
        d | delete)
            DCE_DELETE_CLUSTER="true"
            ;;
        D | delete-only)
            DCE_DELETE_CLUSTER="true"
            DCE_SKIP_CHECK="true"
            DCE_DELETE_ONLY="true"
            DCE_COMMAND="deletecluster"
            ;;
        V)
            echo $(tput setaf 2) 'Verbose mode enabled' $(tput sgr0)
            [[ "${VERBOSE_MODE}" == "true" ]] && USE_RANDOM_COLORS=true && set -x
            VERBOSE_MODE=true
            ;;
        q)
            VERBOSE_MODE=false
            ;;
        f)
            DCE_SKIP_CHECK="true"
            ;;
        ngrok)
            DCE_USE_NGROK="true"
            ;;
        ngrok-url)
            DCE_SKIP_CHECK="true"
            DCE_USE_NGROK="true"
            DCE_COMMAND="ngrokurl"
            ;;
        ngrok-subdomain)
            DCE_USE_NGROK="true"
            DCE_NGROK_SUBDOMAIN="${OPTARG}"
            ;;
        i)
            echo $(docker-machine ip "${DCE_CLUSTER_NAME}-master")
            exit 0
            ;;
        digitalocean)
            [[ ! -z ${_DRIVER_SELECTED} ]] && multiple_drivers
            _DRIVER_SELECTED=true
            DCE_DOCKER_MACHINE_DRIVER=digitalocean
            DIGITALOCEAN_ACCESS_TOKEN=${OPTARG}
            ;;
        do)
            [[ ! -z ${_DRIVER_SELECTED} ]] && multiple_drivers
            _DRIVER_SELECTED=true
            DCE_DOCKER_MACHINE_DRIVER=digitalocean
            ;;
        T | validation-tests)
            DCE_RUN_VALIDATION_TEST=true
            ;;
        validation-tests-only)
            DCE_RUN_VALIDATION_TEST=true
            DCE_COMMAND="validation-tests"
            DCE_SKIP_CHECK="true"
            ;;
        h | help)
            if [ -z "${DCE_INSTALLED}" ]
            then
                echo ${DCE_NAME} is not installed on your system.
                echo Thought you should know.
            else
                echo ${DCE_NAME} is installed. To run just type: ${DCE_NAME}
            fi
            [[ ${opt} == "help" ]] && DCE_SHORT_HELP="false"
            [[ ${opt} == "h" ]] && DCE_SHORT_HELP="true"
            show_usage
            exit 0
            ;;
        *)
            echo Missing arg for param -$OPTARG 1>&2

            exit 1
            ;;
    esac
    DCE_NO_FLAGS="true"
done
[[ -z "${DCE_NO_FLAGS}" ]] && show_short_help && exit 1
if [ "${DCE_SKIP_CHECK}" == "false" ]
then
    (set -o posix; set) | grep DCE_
    echo $(tput setaf 3) Are these options correct? \(Y/N\) $(tput sgr0)
    read ANS
    [[ "$ANS" != "Y" ]] && myEcho exiting && exit 202
fi
[[ ${DCE_COMMAND} == "show_usage" ]] && DCE_COMMAND="makecluster"

cluster_exists(){
    echo $(docker-machine ls -q| grep ${DCE_CLUSTER_NAME} | wc -l)
}

ngrok_url(){
    [[ "$(cluster_exists)" == "0" ]] && echo "Cluster ${DCE_CLUSTER_NAME} doesn't exist" && exit 1
    RANCHER_NGROK_URL=$(docker-machine ssh "${DCE_CLUSTER_NAME}-master" "docker logs rancher-ngrok | grep -iIohE 'http?://[^[:space:]]+'")
    if [[ -z "${RANCHER_NGROK_URL}" ]]
    then
        run_ngrok
    else
        RANCHER_NGROK_URL=$(echo ${RANCHER_NGROK_URL}| rev | cut -d " " -f 1 | rev)
        if [[ ${DCE_COMMAND} == "ngrokurl" ]]
        then
            echo ${RANCHER_NGROK_URL}
        else
            echo You can access rancher at: ${RANCHER_NGROK_URL}
        fi
    fi
}

run_ngrok(){
    : ${DCE_NGROK_IMAGE:=hibooboo2/ngrok}
    if [[ ! -z ${DCE_NGROK_SUBDOMAIN} ]]
    then
        local NGROK_ARGS="-e SUBDOMAIN=${DCE_NGROK_SUBDOMAIN}"
    fi
    docker-machine ssh "${DCE_CLUSTER_NAME}-master" "docker run -d --name=rancher-ngrok -e IP_PORT=$(get_master_ip):80 ${NGROK_ARGS} ${DCE_NGROK_IMAGE}"
    sleep 5
    docker-machine ssh ""
    ngrok_url
}

get_master_ip() {
    echo $(docker-machine ip "${DCE_CLUSTER_NAME}-master")
}

get_project_id()
{
    echo $(curl -s -X GET http://$(get_master_ip)/v1/projects|python -c'import json,sys;print(json.load(sys.stdin)["data"][0]["id"])')
}
create_reg_tokens() # Signature: rancher_server_ip
{
    echo $(curl -s -X POST http://${1}/v1/projects/$(get_project_id)/registrationtokens|python -c'import json,sys; print(json.load(sys.stdin)["links"]["self"])')
}

get_total_project_hosts()
{
    echo $(curl -s http://$(get_master_ip)/v1/projects/$(get_project_id)/hosts|python -c'import json,sys; print(len(json.load(sys.stdin).items()[5][1]))')
}

get_run_cmd()
{
    ip=$(get_master_ip)
    reg_tokens_link=$(create_reg_tokens ${ip})
    sleep 1
    DOCKER_ARG="-e CATTLE_AGENT_IP=$(docker-machine ip ${1})"
    COMMAND=$(curl -s -X GET $reg_tokens_link|python -c'import json,sys; print(json.load(sys.stdin)["command"])')
    echo $(echo $(echo ${COMMAND} | cut -d " " -f 1-3)) ${DOCKER_ARG} $(echo $(echo ${COMMAND} | cut -d " " -f 4-))
    # get then args after sudo docker run and be fore -d
}

create_master(){
    myEcho Starting creation of master
    case ${DCE_DOCKER_MACHINE_DRIVER} in
        virtualbox)
        docker-machine create --driver virtualbox --virtualbox-cpu-count "${DCE_MASTER_CORES}" \
            --virtualbox-memory "${DCE_MASTER_MEM}" --virtualbox-no-share "${DCE_CLUSTER_NAME}-master"
            ;;
        digitalocean)
            docker-machine create --driver digitalocean --digitalocean-access-token ${DIGITALOCEAN_ACCESS_TOKEN} \
            --digitalocean-size "2gb" "${DCE_CLUSTER_NAME}-master"
            ;;
    esac
    docker-machine ssh "${DCE_CLUSTER_NAME}-master" "$(get_start_build_master_command)"
    myEcho Master created.
}

createSlave() {
    myEcho Creating  ${DCE_CLUSTER_NAME}-slave-${1}
    case ${DCE_DOCKER_MACHINE_DRIVER} in
    virtualbox)
        docker-machine create --driver virtualbox --virtualbox-cpu-count "${DCE_SLAVE_CORES}" \
            --virtualbox-memory "${DCE_SLAVE_MEM}" --virtualbox-no-share "${DCE_CLUSTER_NAME}-slave-${1}"
        ;;
    digitalocean)
        docker-machine create --driver digitalocean --digitalocean-access-token ${DIGITALOCEAN_ACCESS_TOKEN} \
            --digitalocean-size "1gb" "${DCE_CLUSTER_NAME}-slave-${1}"
        ;;
    esac
    docker-machine ssh "${DCE_CLUSTER_NAME}-slave-${1}" "$(get_run_cmd "${DCE_CLUSTER_NAME}-slave-${1}")"
}
create_slaves() {
     for i in `seq 1 ${DCE_SLAVES}`;
        do
            myEcho Creating slave ${i}
            createSlave ${i} &
        done
}

run_validation_tests() {
    [[ "${DCE_RUN_VALIDATION_TEST}" != "true" ]] && return 0
    docker-machine ssh "${DCE_CLUSTER_NAME}-master" "docker rm -fv ${DCE_CLUSTER_NAME}_validation_tests || echo No previous tests exist."
    docker-machine ssh "${DCE_CLUSTER_NAME}-master" "docker run -d -e CATTLE_TEST_URL=http://$(get_master_ip) -e CATTLE_IDEMPOTENT_CHECKS=false --privileged -e CATTLE_TEST_PARALLEL_THREADS=4 --name=${DCE_CLUSTER_NAME}_buildmaster_volumes rancher/build-master bash -x /opt/cattle/scripts/git-manager"
    docker-machine ssh "${DCE_CLUSTER_NAME}-master" "docker logs -f ${DCE_CLUSTER_NAME}_buildmaster_volumes"
    docker-machine ssh "${DCE_CLUSTER_NAME}-master" "docker run -d -e CATTLE_TEST_URL=http://$(get_master_ip) -e CATTLE_IDEMPOTENT_CHECKS=false --privileged -e CATTLE_TEST_PARALLEL_THREADS=4 --volumes-from=${DCE_CLUSTER_NAME}_buildmaster_volumes --name=${DCE_CLUSTER_NAME}_validation_tests rancher/build-master bash -x /opt/cattle/scripts/validation-tests"
}

delete_cluster(){
    CLUSTER_EXISTS=$(cluster_exists)
    [[ "${CLUSTER_EXISTS}" != "0" && "${DCE_DELETE_CLUSTER}" != "true" ]] && echo Cluster already exists with ${CLUSTER_EXISTS} nodes && exit 1
    nodes=$(docker-machine ls -q| grep ${DCE_CLUSTER_NAME})
    for i in ${nodes};
    do
        docker-machine rm ${i}
    done
    [[ "${DCE_DELETE_ONLY}" == "true" ]] && exit 0
}

build_cluster()
{
    [[ ${DCE_DELETE_CLUSTER} == "true" ]] && delete_cluster
    if [ "$(cluster_exists)" == 0 ]; then
        local start=$(date -u +"%s")
        create_master
        IP=$(get_master_ip)
        echo -n "Waiting for server to start "

        [[ ${VERBOSE_MODE} == true ]] && set +x
        while sleep 3; do
            if [ "$(curl -s http://${IP}/ping)" == "pong" ]; then
                master=$(date -u +"%s")
                break
            fi
            echo -n "."
        done
        [[ ${VERBOSE_MODE} == true ]] && set -x

        create_slaves

        [[ ${VERBOSE_MODE} == true ]] && set +x

        echo
        echo -n "Waiting for slaves to register "
        while sleep 3; do
            if [ "$(get_total_project_hosts)" == "${DCE_SLAVES}" ]; then
                #Slack
                all_slaves=$(date -u +"%s")
                echo ${DCE_SLAVES} HOSTS found.
                break
            fi
            echo -n "."
        done

        [[ ${VERBOSE_MODE} == true ]] && set -x


        local master_diff=$(($master-$start))
        local slaves_diff=$(($all_slaves-$master))

        if [[ "${DCE_USE_NGROK}" == "true" ]]
        then
            run_ngrok
        fi
        run_validation_tests
        if [[ ! -z "${RANCHER_NGROK_URL}" ]]
        then
            CLUSTER_URL="Ngrok url for cluster is: ${RANCHER_NGROK_URL}"
        else
            CLUSTER_URL="Ip for master is: $(get_master_ip)"
        fi
        cat <<EOF
        $(($master_diff / 60)) minutes and $(($master_diff % 60)) seconds elapsed to create master and start rancher.
        $(($slaves_diff / 60)) minutes and $(($slaves_diff % 60)) seconds elapsed to create slaves and get them all in rancher.
        ${CLUSTER_URL}
EOF
        exit 0
    else
        echo "Cluster ${DCE_CLUSTER_NAME} exists still, or existed and didn't delete add
        -d flag to delete old cluster and make new one."
        exit 69
    fi
}

 main() {
    case ${DCE_COMMAND} in
        makecluster)
            build_cluster
            ;;
        ngrokurl)
            ngrok_url
            ;;
        deletecluster)
            delete_cluster
            ;;
        shorthelp)
            show_short_help
            ;;
        validation-tests)
            run_validation_tests
            ;;
    esac
 }
main

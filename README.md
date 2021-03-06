## Wrapper to deploy Rancher using Docker Machine


=====

**This has only been tested using Mac OS X El Captain and Ubuntu 14.04**

Prerequisites:

- [Docker Machine](https://docs.docker.com/machine/install-machine/)
- After cloning run
```
    git submodule init
    git submodule update
```
If you want to have autocompletion for flags have your ~/.profile:
```
    . ./dce-completion
```
Then create a symlink for `./dce-10-acre.sh` to `/usr/local/bin/dce`
```
    ln -s ./dce-10-acre.sh /usr/local/bin/dce
```
=========

### To deploy a cluster:

```
./dce-10-acre.sh -N <cluster-name> -s <number of nodes>
```

Currently all nodes will be deployed with boot2docker latest iso. The naming convention is:
<clustername>-master
<clustername>-slave-[1:N]

### Get the master IP:

```
./dce-10-acre.sh -i
```
You can hit this IP over port 8080 to get to the UI


=========



dce-10-acre.sh Usage:

    -M - Memory for master node default:2048
        $DCE_MASTER_MEM

    -m - Memory for slave nodes default:1024
        Needs to be im MB ex: -m 1024
        $DCE_SLAVE_MEM

    -C Number of cores to use for the master node (If drive supports this.)
        Needs to be a number ex: -C 2048
        $DCE_MASTER_CORES

    -c Number of cores to use for the slave nodes (If drive supports this.)
        Needs to be a number ex: -c 2
        $DCE_SLAVE_CORES

    -v | --cattle-version Specify cattle version in format {githubUser}/{branch/tag/commitSha}
        ex:
            dce-10-acre.sh -v rancher/v0.106.0
            dce-10-acre.sh -v rancher/56744ac585f5e0aa39ef7568a08049d305cdea05
            dce-10-acre.sh -v rancher/master

    -p | --python-agent-version Similar to -v but for Python agent version.
        ex:
            dce-10-acre.sh -p rancher/v0.59.0
            dce-10-acre.sh -p rancher/304646088882dee48f34b330a0182bfe96cec4fd
            dce-10-acre.sh -p rancher/master

    -H Similar to -v but for Host api version.

    -u Similar to -v but for Ui version.

    -n Similar to -v but for Node agent version.

    -b Similar to -v but for build tools version.

    -N Name of the cluster
        ex: dce-10-acre.sh -N rancher-test-cluster
        Master has -master appended and Nodes/slaves have -slave appended.
        Default cluster name is grabbed from whoami
        $DCE_CLUSTER_NAME

    -h / --help Show this help dialogue.
        ex: dce-10-acre.sh -h

    -V Verbose output. This will display extra text to tell user what is going on while running.
        ex: dce-10-acre.sh -V
        Use flag twice to output messages using random colors per line. And set -x
        ex: dce-10-acre.sh -VV or -V {some other flags} -V

    -f Run with no confirm using all defaults.
        ex: dce-10-acre.sh -f

    -q Run quietly. Meaning set +o
        Still not fully implemented.

    -d | --delete Delete the cluster if it already exists.
        ex: dce-10-acre.sh -d
        $DCE_DELETE_CLUSTER
    -D | --delete-only Delete the cluster if it already exists. Then exit. (Preempts other flags.)
        When used no other commands will occur. Cluster will just be deleted.
        ex:
            dce-10-acre.sh -D
            dce-10-acre.sh --delete-only
        $DCE_DELETE_ONLY

    -i Get the master ip of the cluster. Can use with -N if you have multiple clusters.
        ex: dce-10-acre.sh -i
        Might print out 192.168.99.100

    --digitalocean ${DIGITALOCEAN_ACCESS_TOKEN}  Launch vms using Digital Ocean.
        This flag cannot be used with -C -c -M or -M.

    --do Create cluster using Digital Ocean. Assumes ${DIGITALOCEAN_ACCESS_TOKEN} is set in environment.
            This flag cannot be used with -C -c -M or -M.

    -T | --validation-tests Run the validation tests.
        This will use buildmaster to run the validation tests on the cluster in a container on the master.
    --validation-tests-only Run the validation tests on an existing cluster. (Can combine with -N)
        ex: dce-10-acre.sh -N cluster-3 --validation-tests-only


Example usage:

    All defaults: virtual box with 1 master 4 cores 2048 mb ram 1 slaves 2 cores 1024 mb
    ram master for all components from rancher.
        dce-10-acre.sh -f
        or
        dce-10-acre.sh -C 4 -M 2048 -c 2 -m 1024 -s 1
        or
        dce-10-acre.sh --digitalocean 262415404adaf7be5e5019680014e85e7e70f47d5bceee39668d4130a69a6b74




### Contact
For bugs, questions, comments, corrections, suggestions, etc., open an issue in [hibooboo2/docker-machine-ranch](//github.com/hibooboo2/docker-machine-ranch/issues).

Or just [click here](//github.com/hibooboo2/docker-machine-ranch/issues/new) to create a new issue.

# License
Copyright (c) 2014-2015 <mailto>wizardofmath@gmail.com</mailto>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.



## Wrapper to deploy Rancher using Docker Machine
=====
Prerequisites:

- [Docker Machine](https://docs.docker.com/machine/install-machine/)
- After cloning run
```
    git submodule init
    git submodule update
```
=========

### To deploy a cluster:

```
%DCE_NAME% -N <cluster-name> -s <number of nodes>
```

Currently all nodes will be deployed with boot2docker latest iso. The naming convention is:
<clustername>-master
<clustername>-slave-[1:N]

### Get the master IP:

```
%DCE_NAME% -i
```
You can hit this IP over port 8080 to get to the UI


=========


%USAGE%



### Contact
For bugs, questions, comments, corrections, suggestions, etc., open an issue in [hibooboo2/docker-machine-ranch](//github.com/hibooboo2/docker-machine-ranch/issues).

Or just [click here](//github.com/hibooboo2/docker-machine-ranch/issues/new) to create a new issue.

# License
Copyright (c) 2014-2015 wizardofmath@gmail.com

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.



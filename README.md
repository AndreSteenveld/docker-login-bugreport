# docker-login-bugreport
Minimal reproduction of an issue with docker login

# Description

Logging in to a local running registry fails in some cases.

# Steps to reproduce

To create the minimal reproduction case that looks like what I am trying to achieve I've created a small repository which can be found here: https://github.com/AndreSteenveld/docker-login-bugreport. I am running this on Hyper-V machine using Debian 10, more details on that in the "Additional environment details" section.

0. In the "docker-login-bugreport" directory
1. Run `docker-compose run --rm registry-builder bash --login`
2. In the resulting shell I'd like to use `docker login` to login to the registry which was also started to do this I run `docker login --username docker --password docker http://bootstrap-registry:5000`
3. I expect a successfull login as the registry is configured to use `silly` authentication but it fails with the message: 

```
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Error response from daemon: Get http://bootstrap-registry:5000/v2/: dial tcp: lookup bootstrap-registry on 172.18.44.193:53: no such host
```

Given that this looks like the name `bootstrap-registry` can't be found I wanted to validate that with `nslookup`. Which gave me the following output:

```
root@7084a5d7d772:/tmp/context# nslookup bootstrap-registry
Server:         127.0.0.11
Address:        127.0.0.11#53

Non-authoritative answer:
Name:   bootstrap-registry
Address: 172.19.0.2

root@7084a5d7d772:/tmp/context#
```

4. Not to be deterred I use the IP of the repository to login never the less: `docker login --username docker --password docker http://172.19.0.2:5000`. This gives me a TLS error

```
root@7084a5d7d772:/tmp/context# docker login --username docker --password docker http://172.19.0.2:5000
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Error response from daemon: Get https://172.19.0.2:5000/v2/: http: server gave HTTP response to HTTPS client
root@7084a5d7d772:/tmp/context#
```

To validate that the DNS lookup in `docker login` is the failing I used `curl` to get a list of images from the registry:

```
root@7084a5d7d772:/tmp/context# curl -X GET http://docker:docker@bootstrap-registry:5000/v2/_catalog
{"repositories":[]}
```

Also just pushing an image to the registry by tagging it with the host name or IP fails for the same reasons (failing the DNS lookup and expecting a https connection) tagging it with the IP of the registry, seems to work fine. Using the name also results in a lookup error:

```
root@7084a5d7d772:/tmp/context# docker pull hello-world
# Snip the output from pull

root@7084a5d7d772:/tmp/context# docker image tag hello-world:latest bootstrap-registry:5000/hello-world:latest
root@7084a5d7d772:/tmp/context# docker push bootstrap-registry:5000/hello-world:latest
The push refers to repository [bootstrap-registry:5000/hello-world]
Get http://bootstrap-registry:5000/v2/: dial tcp: lookup bootstrap-registry on 172.18.44.193:53: no such host

root@7084a5d7d772:/tmp/context# docker image tag hello-world:latest 172.19.0.2:5000/hello-world:latest
root@7084a5d7d772:/tmp/context# docker push 172.19.0.2:5000/hello-world:latest
The push refers to repository [172.19.0.2:5000/hello-world]
Get https://172.19.0.2:5000/v2/: http: server gave HTTP response to HTTPS client
```

# What were my expectations

Logging in using `docker login` should work this as the following sequence does work (in a terminal on the host):

```
docker@docker-host:/c/engineering/source/repos/docker-login-bugreport$ docker run --rm --detach --name registry --publish 5000:5000 registry:2
d50e104b2552cbba3c9915caf927d1964250b64644b117870f2c1165f97c24a2
docker@docker-host:/c/engineering/source/repos/docker-login-bugreport$ docker login 127.0.0.1:5000
Username: docker
Password:
WARNING! Your password will be stored unencrypted in /home/docker/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
docker@docker-host:/c/engineering/source/repos/docker-login-bugreport$
```

# `docker version` and `docker info`

The output of `docker version` and `docker info` were taken from inside the container, I did start another instance as I initially forgot to do this:

```
root@3d98c5e16d0a:/tmp/context# docker version
Client: Docker Engine - Community
 Version:           19.03.8
 API version:       1.40
 Go version:        go1.12.17
 Git commit:        afacb8b7f0
 Built:             Wed Mar 11 01:22:56 2020
 OS/Arch:           linux/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          19.03.13
  API version:      1.40 (minimum version 1.12)
  Go version:       go1.13.15
  Git commit:       4484c46d9d
  Built:            Wed Sep 16 17:01:25 2020
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.2.6
  GitCommit:        894b81a4b802e4eb2a91d1ce216b8817763c29fb
 runc:
  Version:          1.0.0-rc8
  GitCommit:        425e105d5a03fabd737a126ad93d62a9eeede87f
 docker-init:
  Version:          0.18.0
  GitCommit:        fec3683
root@3d98c5e16d0a:/tmp/context# docker info
Client:
 Debug Mode: false

Server:
 Containers: 2
  Running: 2
  Paused: 0
  Stopped: 0
 Images: 41
 Server Version: 19.03.13
 Storage Driver: overlay2
  Backing Filesystem: extfs
  Supports d_type: true
  Native Overlay Diff: true
 Logging Driver: json-file
 Cgroup Driver: cgroupfs
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 894b81a4b802e4eb2a91d1ce216b8817763c29fb
 runc version: 425e105d5a03fabd737a126ad93d62a9eeede87f
 init version: fec3683
 Security Options:
  apparmor
  seccomp
   Profile: default
 Kernel Version: 4.19.0-5-amd64
 Operating System: Debian GNU/Linux 10 (buster)
 OSType: linux
 Architecture: x86_64
 CPUs: 6
 Total Memory: 3.853GiB
 Name: docker-host
 ID: A3RO:YO4B:XW25:IRLE:VUIZ:2OM4:53X4:EP2K:L37I:AS22:26JW:V7BW
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  0.0.0.0:5000
  bootstrap-registry:5000
  localhost:5000
  registry:5000
  127.0.0.0/8
 Live Restore Enabled: false

WARNING: API is accessible on http://localhost:2375 without encryption.
         Access to the remote API is equivalent to root access on the host. Refer
         to the 'Docker daemon attack surface' section in the documentation for
         more information: https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface
WARNING: No swap limit support
```

The output of running `uname -a` on the host machine, which is a Hyper-V virtual machine with a samba client to access the C drive:
```
docker@docker-host:/c/engineering/source/repos/docker-login-bugreport$ uname -a
Linux docker-host 4.19.0-5-amd64 #1 SMP Debian 4.19.37-5+deb10u2 (2019-08-08) x86_64 GNU/Linux
```

I've tried adding the names of the containers as "Insecure registries" so my `/etc/docker/daemon.json` looks like this:

```json
{
    "dns" : [ "8.8.8.8", "1.1.1.1" ],
    "allow-nondistributable-artifacts": [
        "localhost:5000",
        "registry:5000",
        "bootstrap-registry:5000"
    ],
    "insecure-registries": [
        "localhost:5000",
        "registry:5000",
        "bootstrap-registry:5000",
        "0.0.0.0:5000"
    ],
    "hosts": [ "tcp://localhost:2375", "unix:///var/run/docker.sock" ]
}
```

# Summarized

1. I am not completly sure but it seems like `docker login` doesn't correctly lookup urls
2. `docker login` uses HTTPS even if the URL explicitly specifies HTTP




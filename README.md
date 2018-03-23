# Object Detection at the Edge

## Prerequisites
Install the following tools on your Edge device: [Docker](https://www.docker.com/). Use the following links to help you:
* [Docker Community Edition installation](https://www.docker.com/community-edition#/download)

My Edge device is currently running Fedora 27, with the following versions of the abovementionned packages:
* Docker version 18.02.0-ce, build fc4de44

We use IP cameras from [SV3C](http://www.sv3c.com/), more specifically the POE models (that can do 1080p): http://www.sv3c.com/POE-IP-Camera.html

## Getting ready
1. Clone this repository locally: `git clone https://github.com/inc0/video_detection`
2. Make sure [Docker](https://www.docker.com/) is running: `sudo systemctl start docker`
3. Put yourself in the cloned folder: `cd video_detection`

## Running the Object Detection algorithm in containers

### Setting up [Kubernetes](https://kubernetes.io/)

1. On Fedora 27
Sources of inspiration (aka online guides):
* https://kubernetes.io/docs/setup/independent/install-kubeadm/
* https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/

```
sudo dnf install kubernetes-client kubernetes-node kubernetes-master kubernetes-kubeadm
```
That installs Kubernetes 1.9.1 on your Fedora 27 system.

Modify the `kubelet` Cgroup driver to use the same as Docker:
```
$ sudo docker info | grep -i cgroup
$ sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/kubeadm.conf
```
*Note:* we will reload the daemon and restart the `kubelet` service later on (see below)

Other preparation tasks:
```
$ sudo swapoff -a
$ sudo systemctl disable firewalld
$ sudo systemctl stop firewalld
$ sudo systemctl enable kubelet.service

```

*Note*: using `swapoff` does not turn off the swap permanently, it will be active again after a reboot. If you wish to make this change permanent, do this:
```
sudo sed -i "s/\/dev\/mapper\/fedora-swap/#\/dev\/mapper\/fedora-swap/g" /etc/fstab
```

Make sure `docker` is using `runc` and fix the `CNI` bin path used:
```
$ sudo docker info | grep Run
$ sudo sed -i "s/--cni-bin-dir=\/usr\/libexec\/cni/--cni-bin-dir=\/usr\/libexec\/cni --cni-bin-dir=\/opt\/cni\/bin/g" /etc/systemd/system/kubelet.service.d/kubeadm.conf
```

Restart the kubelet service
```
$ sudo systemctl daemon-reload
$ sudo systemctl restart kubelet
```

**Note**: running `sudo kubeadm init` on my system takes the network interface down... not sure why, under investigation. **[Solved]**: Docker was using `cc-runtime` by default... it worked after changing this back to `runc`.

Create the Cluster
```
$ sudo kubeadm init --pod-network-cidr=192.168.150.0/24
$ cd k8s && wget https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml && cd ..
$ sed -i "s/192.168.0.0\/16/192.168.150.0\/24/g" k8s/calico.yaml
$ kubectl apply -f k8s/calico.yaml
```
**Note:** I really don't know what valid or not in terms of `--pod-network-cidr`, I'm mostly trying to avoid any clash with other similar subnets I have locally.

**Important:** write down the `kubeadm join` command that will be printed out at the end of the initialisation phase. It will be used to get nodes to join the cluster.

Allow non-root users to use `kubectl` (optional)
```
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Verify that all containers are running:
```
$ kubectl get pods --all-namespaces
```

Allow pods to be run on your master (optional)
```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

2. On Clear Linux (using Clear Containers)

```
$ sudo swupd bundle-add cloud-native-basic
```

```
$ sudo swapoff -a
```

**Note:** you can turn the `swap` off permanently by `???`.

You may get this error when trying to join the cluster network:
```
	[ERROR CRI]: unable to check if the container runtime at "/var/run/dockershim.sock" is running: exit status 1
```
If that's the case, add `--ignore-preflight-errors=cri` to the `kubeadm join <blah blah>` command-line.

**To be completed - still having some networking issues**

#### Running the Object and Zombies detection algorithms
This section assumes that you have a working configuration based on Kubernetes. The steps above are not complete in that regard.

In order to run the demo, here are the steps to follow (at a high-level):
1. Build the containers you will need
2. Start the private registry
3. Upload the containers (in case they are not yet available in the private registry
4. Start the various services
5. Visualize the output
6. Shutting down the demo (and restarting it)

Because this document would become too long with this, I have moved this section in a dedicated file named [running-the-demo.md](./running-the-demo.md)


### Using [Docker Compose](https://docs.docker.com/compose/overview/)

#### Install
Follow these on-line instructions: [Docker Compose installation](https://docs.docker.com/compose/install/). I have tested this on Fedora 27 using this version of `docker-compose`:
* docker-compose version 1.19.0, build 9e633ef

**Note:** you do not need to need to build any Docker container. It will be built automatically for you if not yet available. See the `build` instruction in the [`docker-compose.yml`](./docker-compose.yml) file.

#### Running the Object Detection algorithm

1. On Fedora 27
*Note:* unless you have installed Docker and performed [these post-installation steps](https://docs.docker.com/install/linux/linux-postinstall/), you will need to use `sudo` to use `docker-compose`. For some reason, it does not find the `docker-compose` executable and I have to use the full path to it, i.e. `sudo /usr/local/bin/docker-compose up` (to be investigated later, or maybe a reboot will solve it).

  1. Set-up the IP camera following the online [User Guides](http://www.sv3c.com/Instruction-and-Software-For-H-264-POE-and-Wired-IP-Camera-L-series-.html)
  2. Take note of the IP address assigned to the camera

*We use an environment variable to pass the IP address of the camera to the container that will capture the video stream. The name of the variable is `IP_CAMERA`.*
  3. Start the Object Detection service
```
sudo IP_CAMERA=192.168.0.130 /usr/local/bin/docker-compose up
```
  4. Open a broswer at http://0.0.0.0:5000 to see the results

2. On Clear Linux
It is possible to run the same set-up on Clear Linux. Unfortunately, it is **not** possible to use [Clear Containers](https://clearlinux.org/containers) for this yet as name resolution does not work in either [Docker Compose](https://docs.docker.com/compose/overview/) or [Docker Swarm](https://docs.docker.com/engine/swarm/). See the ["Name resolution does not work when using docker-compose"](https://github.com/clearcontainers/runtime/issues/1042) issue for more details.

Same as for Fedora 27 (or any other OS really), install [Docker](https://www.docker.com/) and [docker-compose](https://docs.docker.com/compose/overview/). Use the following guides to help you:
* [Installing Clear Containers 3.0 on Clear Linux](https://github.com/clearcontainers/runtime/blob/master/docs/clearlinux-installation-guide.md)
* Install `docker-compose`:
```
$ sudo curl -L https://github.com/docker/compose/releases/download/1.19.0/docker-compose-`uname -s`-`uname -m` -o /usr/bin/docker-compose
$ sudo chmod +x /usr/bin/docker-compose
```

Because of the current issue with Clear Containers 3, we have to change the default behaviour of Docker when running in Clear Linux (bare metal). The background is that, by default, it will pick the Clear Containers 3 runtime (`cc-runtime`) when running bare-metal so we need to force the system to **not** do that.

One way to achieve this (not sure whether it's the best way) is to modify the `docker.service` file (`/lib/systemd/system/docker.service`) and change the `ExecStart` line to this:
```
ExecStart=/usr/bin/dockerd --storage-driver=overlay2 --default-runtime=runc
```

Now reload and restart the daemon:
```
$ sudo systemctl daemon-reload
$ sudo systemctl restart docker
```

Verify that the `runc` runtime is being used:
```
sudo docker info | grep Run
```

You are now ready to continue from [Running the Object Detection algorithm](#running-the-object-detection-algorithm)


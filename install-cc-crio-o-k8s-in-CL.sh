#!/bin/bash

set -x -e

# Install Bundles:
# os-utils-gui-dev is installed as it is the only bundle that contains pkg-config
sudo swupd bundle-add containers-virt cloud-native-basic os-clr-on-clr-dev os-utils-gui-dev

# Replace installed docker docker 1.12.6 which does
docker_version="1.12.6"
docker_tar="docker-${docker_version}.tgz"
curl -L -O "https://get.docker.com/builds/Linux/x86_64/${docker_tar}"
tar -xvf "$docker_tar"
pushd docker
sudo cp ./* /usr/bin/
popd
rm -rf ./docker "$docker_tar"

# Also I built and installed libdevmapper manually as I think we do not ship it in CL:
devmapper_version="2.02.172"
curl -LOk ftp://sources.redhat.com/pub/lvm2/releases/LVM2.${devmapper_version}.tgz
tar -xf LVM2.${devmapper_version}.tgz
pushd LVM2.${devmapper_version}/
./configure
make -j$(nproc) libdm
sudo -E PATH=$PATH sh -c "make libdm.install"
popd
rm -rf LVM2.${devmapper_version}/ LVM2.${devmapper_version}.tgz

#create /etc/hosts file (or copy it from /usr/share/defaults/etc/hosts)
sudo cp /usr/share/defaults/etc/hosts /etc/hosts

# Modify k8s systemd service:

k8s_systemd_file="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
k8s_systemd_dir="/etc/systemd/system/kubelet.service.d"
sudo mkdir -p "$k8s_systemd_dir"
cat <<EOF | sudo tee "$k8s_systemd_file"
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_DNS_ARGS=--cluster-dns=10.96.0.10 --cluster-domain=cluster.local"
Environment="KUBELET_AUTHZ_ARGS=--authorization-mode=Webhook --client-ca-file=/etc/kubernetes/pki/ca.crt"
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=/var/run/crio.sock --runtime-request-timeout=30m"
Environment="KUBELET_CADVISOR_ARGS=--cadvisor-port=0"
Environment="KUBELET_CERTIFICATE_ARGS=--rotate-certificates=true --cert-dir=/var/lib/kubelet/pki"
ExecStart=
ExecStart=/usr/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_SYSTEM_PODS_ARGS \$KUBELET_NETWORK_ARGS \$KUBELET_DNS_ARGS \$KUBELET_AUTHZ_ARGS \$KUBELET_CADVISOR_ARGS \$KUBELET_CERTIFICATE_ARGS \$KUBELET_EXTRA_ARGS
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=/var/run/crio.sock --runtime-request-timeout=30m"
EOF

# install CRIO and CNI plugins
sudo mkdir -p /etc/systemd/system
export GOPATH="$HOME/go"
go get github.com/clearcontainers/tests
pushd "$GOPATH/src/github.com/clearcontainers/tests"
.ci/install_cni_plugins.sh
.ci/install_crio.sh

# Modify /etc/crio/crio.conf to use cc-runtime installed in /usr/bin/
sudo sed -i 's/^runtime_untrusted_workload.*$/runtime_untrusted_workload = "\/usr\/bin\/cc-runtime"/' /etc/crio/crio.conf

# Reload and restart systemd services
sudo systemctl daemon-reload
sudo systemctl restart crio
sudo systemctl restart docker
sudo systemctl restart cc3-proxy

# Run this init script to initialize the kubelet services:
pushd integration/kubernetes
./init.sh
popd
popd

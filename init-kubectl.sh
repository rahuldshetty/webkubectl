#!/bin/bash
set -e

arg1=$1
arg2=$2
arg3=$3

mkdir -p /nonexistent
mount -t tmpfs -o size=${SESSION_STORAGE_SIZE} tmpfs /nonexistent
cd /nonexistent
cp /root/.bashrc ./
echo 'source /opt/kubectl-aliases/.kubectl_aliases' >> .bashrc
echo 'PS1="> "' >> .bashrc
mkdir -p .kube

# setup kubectl-exec-as
mkdir -p bin
cp -r /root/.krew/bin bin
export PATH=$PATH:bin

export HOME=/nonexistent
if [ -z "${arg3}" ]; then
    echo $arg1| base64 -d > .kube/config
else
    echo `kubectl config set-credentials webkubectl-user --token=${arg2}` > /dev/null 2>&1
    echo `kubectl config set-cluster kubernetes --server=${arg1}` > /dev/null 2>&1
    echo `kubectl config set-context kubernetes --cluster=kubernetes --user=webkubectl-user` > /dev/null 2>&1
    echo `kubectl config use-context kubernetes` > /dev/null 2>&1
fi

if [ ${KUBECTL_INSECURE_SKIP_TLS_VERIFY} == "true" ];then
    {
        clusters=`kubectl config get-clusters | tail -n +2`
        for s in ${clusters[@]}; do
            {
                echo `kubectl config set-cluster ${s} --insecure-skip-tls-verify=true` > /dev/null 2>&1
                echo `kubectl config unset clusters.${s}.certificate-authority-data` > /dev/null 2>&1
            } || {
                echo err > /dev/null 2>&1
            }
        done
    } || {
        echo err > /dev/null 2>&1
    }
fi

chown -R nobody:nogroup .kube

export TMPDIR=/nonexistent

default_user="deepthought"
pod_name=$(kubectl get pods |grep ${arg2} | awk '{print $1}')

# exec su -s /bin/bash nobody
# Switch to nobody user and connect to the given pod
if [ "${arg2}" ]; then
    exec su -s "/bin/bash" -c "PATH=$PATH:bin kubectl exec-as -u ${default_user} ${pod_name} -- bash" nobody
    #exec su -s "/bin/bash" -c "kubectl exec -it deployment/${arg2} -- bash" nobody
else
   echo "Permission Denied!"
fi
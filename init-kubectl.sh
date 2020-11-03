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

default_user="nobody"
pod_name=$(kubectl get pods -l --field-selector 'status.phase==Running' app=${arg2} | grep -m 1 ${arg2} | awk '{print $1}')

exec_command="kubectl exec -it -c ${arg2} ${pod_name}  -- sh -c \"exec su -s /bin/sh ${default_user}\" "

# exec su -s /bin/bash nobody
# Switch to nobody user and connect to the given pod
if [ -z $pod_name ]; then
    echo "Connection failed. Please try again."
elif [ "${arg2}" ]; then
    exec su -s "/bin/bash" -c "${exec_command}" nobody
else
   echo "Permission Denied!"
fi

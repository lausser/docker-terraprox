# docker-terraprox
Dockerfile, terraform + proxmox provider + sometimes patches

```bash
cat ENV
PM_USER=packer@pve
PM_PASS=***
PM_API_URL=https://proxmox:8006/api2/json
# the proxmox template
DISTRIBUTION=sles-15.2
# register ip address under nslookup/{vm_name}
##CONSUL_ADDRESS=consul-ui.infra-build"
# set VM password via cloud-init
SSH_PASSWORD=***
# VM_NAME=
# either VM_NAME or DISTRIBUTION(mandatory)+PRODUCT(not yet mandatory)+UNIQUE_TAG
# PRODUCT="omd"
# UNIQUE_TAG="dnstest"
# if empty, VM name will be "b-${product}-${distri}-${uuid}"

docker run \
    --env-file ENV \
    --rm -it [--entrypoint /bin/sh]  lausser/terraprox (apply|destroy)

```

## Kubernetes

The folder *k8s* contains the necessary files to create and destroy Proxmox VMs through kubernetes jobs.  
First the cfgmap_*.yml files must be applied. They contain the environment variables and scripts. (runscript.sh is for debugging purposes, later you can leave this away and directly jump to the containers' entrypoint.sh)  
*cfgmap_env_infra.yml* contains Proxmox credentials and can stay forever. *cfgmap_env_omd.yml* and especially *cfgmap_env_uuid.yml* contain values which might (or in the case of uuid, *should*) change after every run.

### Create a VM
This pod runs **terraform apply** and registers the ip address in a consul k/v store. The key is the vm_name.

```bash
kubectl -n dnstest apply -f create_vm.yml
# wait until vm is up
kubectl -n dnstest wait --for=condition=complete --timeout=24h job/create-vm
kubectl -n dnstest delete -f create_vm.yml
kubectl -n dnstest wait --for=delete --timeout=24h job/create-vm
```

### Use the VM
You can for example run an ansible container.
```bash
kubectl -n dnstest apply -f run_ansible.yml
kubectl -n dnstest wait --for=condition=complete --timeout=24h job/ansible

cat run_ansible.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ansible
data:
  runscript.sh: |
    #!/bin/bash
    vm_name=$1
    ip=$(curl "http://consul-ui.infra-build/v1/kv/nslookup/${vm_name}?dc=dc1&raw=1)
    # git clone all the needed ansible roles
    ...
```

### Destroy a VM
This pod just needs the same vm_name as the create-pod, then it will run **terraform destroy**.
```bash
kubectl -n dnstest apply -f destroy_vm.yml
kubectl -n dnstest wait --for=condition=complete --timeout=24h job/destroy-vm
kubectl -n dnstest delete -f destroy_vm.yml
kubectl -n dnstest wait --for=delete --timeout=24h job/destroy-vm
```



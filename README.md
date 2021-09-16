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

### Try the container on the command line
```bash
kubectl -n argo run -it --rm --image lausser/terraprox debug --command /bin/bash
```

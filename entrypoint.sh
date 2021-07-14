#! /bin/bash


mkdir /home/terraform/.ssh && \
chmod 700 /home/terraform/.ssh && \
ssh-keygen -f /home/terraform/.ssh/id_rsa -N ""

virtualization=${VIRTUALIZATION:-proxmox}
distro=${DISTRIBUTION:-centos-7.7}
product=${PRODUCT:-omd}
echo distro is $distro
echo product is $product

# this tag is used to make the vm name unique
if [ -z "$UNIQUE_TAG" ]; then
  uuid=$(uuidgen)
  uuid=${uuid%%-*}
else
  uuid=${UNIQUE_TAG##*-}
fi
echo uuid is $uuid

# the name of the vm, my be derived from uuid
if [ -z "$VM_NAME" ]; then
  vmname="b-${uuid}"
else
  vmname=${VM_NAME}
fi
echo vmname is $vmname

if [ $virtualization = "proxmox" -a -n "$PM_NODE" ]; then
  # PM_NODE can be a comma-separated list of proxmox nodes
  # one of them will be selected by chance.
  PM_NODE=${PM_NODE// /}
  if [[ "$PM_NODE" =~ , ]]; then
    IFS="," read -a nodes <<< $PM_NODE
    declare -p nodes;
    PM_NODE=${nodes[$(shuf -n 1 -i 0-$(("${#nodes[@]}" -1)))]}
  fi
  VAR_TARGET_NODE="-var target_node=$PM_NODE"
fi

if [ -z "$VM_DESC" ]; then
  # a short description of the vm
  vmdesc="${product} on ${distro} in workflow ${uuid}"
else
  vmdesc=${VM_DESC}
fi

if [ -n "$CONSUL_ADDRESS" ]; then
  # terraform state will be saved to consul
  cat > backend.tf <<EOTF
terraform {
  backend "consul" {
    address = "${CONSUL_ADDRESS}"
    scheme  = "http"
    path    = "terraform/${vmname}"
  }
}
EOTF
  cat > consul_node.tf <<EOTF
provider "consul" {
  address    = "${CONSUL_ADDRESS}"
  #datacenter = "dc1"
}

resource "consul_keys" "nslookup" {
  # key is the vm name, value is the ip address
  key {
    path   = "nslookup/\${var.vm_name}"
    value  = proxmox_vm_qemu.cloudinit-vm.ssh_host
    delete = true
  }
}

# can be used later for dns lookups, services
resource "consul_node" "hostname" {
  name    = var.vm_name
  address = proxmox_vm_qemu.cloudinit-vm.ssh_host
}
EOTF
  cat > consul_service.tf.no <<EOTF
resource "consul_service" "node_exporter" {
  name = "node_exporter"
  node = var.vm_name
  port = 9100
  tags = ["prometheus", "node_exporter"]
  check {
    check_id                          = "service:node_exporter"
    name                              = "Prometheus Node Exporter"
    status                            = "passing"
    http                              = "http://\${proxmox_vm_qemu.cloudinit-vm.ssh_host}:9100"
    tls_skip_verify                   = true
    method                            = "GET"
    interval                          = "60s"
    timeout                           = "10s"
    deregister_critical_service_after = "120s"
  }
}
EOTF
fi

for i in ${virtualization}/*.tf.txt
do
  cp $i $(basename $i .txt)
done

terraform init

export TF_LOG=TRACE
export TF_LOG_PATH="terraform.log"

if [ "$1" == "passthrough" ]; then
  terraform $*

elif [ "$1" == "apply" ]; then
  if [ "$virtualization" == "proxmox" ]; then
    terraform apply \
      -var ssh_password="$SSH_PASSWORD" \
      -var vm_clone=t-${distro} \
      -var vm_name=${vmname} \
      -var "vm_desc=${vmdesc}" \
      -var cpu_sockets=2 \
      -var cpu_cores=4 \
      -var memory=32768 \
      --auto-approve \
      -input=false     ${VAR_TARGET_NODE:-}
  elif [ "$virtualization" == "aws" ]; then
    if [[ $distro =~ ^ami ]]; then
      ami=$distro
      vmuser=packer
    elif [ $distro == "debian-10.10" ]; then
      ami="ami-084bc6192f5170801"
      vmuser=admin
    fi
    terraform apply \
      -var ssh_password="$SSH_PASSWORD" \
      -var instance_ami=${ami} \
      -var ssh_user=${vmuser} \
      --auto-approve \
      -input=false     ${VAR_TARGET_NODE:-}
  fi

elif [ "$1" == "destroy" ]; then
  terraform destroy \
    --auto-approve -input=false
  if { grep -q "Error: rbd error: rbd: listing images failed:" terraform.log; }; then
    # concurrent operations 
    # Could not remove disk 'ceph01:vm-117-cloudinit', check manually: cfs-lock 'storage-ceph01' error: got lock request timeout
    # Could not remove disk 'ceph01:base-106-disk-0/vm-117-disk-0', check manually: cfs-lock 'storage-ceph01' error: got lock request timeout
    # retry after a random time
    rm -f terraform.log
    sleep $(($RANDOM %300))
    terraform destroy \
      --auto-approve -input=false
  fi

elif [ "$1"  == "cleanup" ]; then
  if [ -n "$CONSUL_ADDRESS" ]; then
    rm -r backend.tf
    echo "yes" | TF_INPUT="true" terraform init -force-copy
    key=$(echo -n "terraform/${vmname}" | sed -e '#/#%2F#g')
    echo curl --request DELETE http://${CONSUL_ADDRESS}/v1/kv/$key
    curl --request DELETE http://${CONSUL_ADDRESS}/v1/kv/$key
  fi

elif [ "$1"  == "sleep" ]; then
  sleep 3600

else
  echo unknown arg ${1:-empty-}
  exit 1
fi

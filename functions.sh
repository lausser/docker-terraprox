#! /bin/bash

run_terraform_apply() {
  local virtualization="$1"
  export TF_LOG=TRACE
  export TF_LOG_PATH="terraform.log"
  rm -f terraform.log
  rm -f terraform.apply.log
  set -o pipefail
  terraform apply \
    -var-file ${virtualization}_vars.tfvars \
    --auto-approve \
    -input=false |& tee -a terraform.apply.log
  terraformrc=$?
  if [[ $terraformrc -ne 0 ]]; then
    # Error: Error acquiring the state lock
    # Error: Plugin did not respond
    # Error: Duplicate" terraform.log
    # maybe concurrent operations
    # retry after a random time
    cat terraform.log
    if grep -q "Error acquiring the state lock" terraform.apply.log; then
      id=$(awk -F: '/ID:/ { print $2 }' terraform.apply.log)
      echo try to unlock
      sleep $(($RANDOM %10))
      terraform force-unlock -force ${id}
    else
      sleep $(($RANDOM %60))
      run_terraform_destroy ${virtualization}
    fi
    sleep $(($RANDOM %60))
    rm -f terraform.log
    terraform apply \
      -var-file ${virtualization}_vars.tfvars \
      --auto-approve \
      -input=false |& tee -a terraform.apply.log
    terraformrc=$?
  fi
  return $terraformrc
}

run_terraform_destroy() {
  local virtualization="$1"
  export TF_LOG=TRACE
  export TF_LOG_PATH="terraform.log"
  rm -f terraform.log
  rm -f terraform.destroy.log
  set -o pipefail
  terraform destroy \
    -var-file ${virtualization}_vars.tfvars \
    --auto-approve -input=false |& tee -a terraform.destroy.log
  terraformrc=$?
  if [[ $terraformrc -ne 0 ]]; then
    cat terraform.log
    # Error: rbd error: rbd: listing images failed:
    # Error: unable to activate storage 'nfs-backup' - directory '/mnt/pve/nfs-backup' does not exist or is unreachable
    # Could not remove disk 'ceph01:vm-117-cloudinit', check manually: cfs-lock 'storage-ceph01' error: got lock request timeout
    # Could not remove disk 'ceph01:base-106-disk-0/vm-117-disk-0', check manually: cfs-lock 'storage-ceph01' error: got lock request timeout
    sleep $(($RANDOM %300))
    terraform destroy \
      -var-file ${virtualization}_vars.tfvars \
      --auto-approve -input=false |& tee -a terraform.destroy.log
    terraformrc=$?
  fi
  return $terraformrc
}

create_ssh_key() {
  mkdir /home/terraform/.ssh
  chmod 700 /home/terraform/.ssh
  ssh-keygen -f /home/terraform/.ssh/id_rsa -N ""
}

enable_consul() {
  local virtualization="$1"
  for i in consul/*.tf
  do
    echo cp $i .
    cp $i .
  done
  cat <<==EOTFVAR > consul_vars.tfvars
consul_address = "${CONSUL_ADDRESS}"
==EOTFVAR
} 

check_environment() {
  local virtualization="$1"
  if [[ "${virtualization}" == "aws" ]]; then
    if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
      echo AWS_SECRET_ACCESS_KEY is not set
      exit 1
    fi
  elif [[ "${virtualization}" == "hcloud" ]]; then
    if [[ -z "${HCLOUD_TOKEN}" ]]; then
      echo HCLOUD_TOKEN is not set
      exit 1
    fi
  elif [[ "${virtualization}" == "proxmox" ]]; then
    if [[ -z "${PM_PASS}" ]]; then
      echo PM_PASS is not set
      exit 1
    fi
  fi
}

setup_tf_files() {
  local virtualization="$1"
  echo virtualization is ${virtualization}
  for i in ${virtualization}/*.tf
  do
    echo cp $i .
    cp $i .
  done
}

setup_tfvars() {
  local virtualization="$1"
  local vmname="$2"
  local vmdesc="$3"
  local distro="$4"
  local otf_ssh_password_encrypted=$(python3 -c 'import crypt; import os; print( crypt.crypt(os.environ["SSH_PASSWORD"]+os.environ["UNIQUE_TAG"], "$6$saltsalt$"))')
  setup_tfvars_${virtualization} "${vmname}" "${vmdesc}" "${distro}"
  # terraform apply will use SSH_PASSWORD to initially run ansible
  # ansible will set the root/packer password to SSH_PASSWORD+UNIQUE_TAG
  cat <<==EOTFVAR >> ${virtualization}_vars.tfvars
otf_ssh_password_encrypted = "${otf_ssh_password_encrypted}"
==EOTFVAR
}

setup_tfvars_proxmox() {
  local vmname="$1"
  local vmdesc="$2"
  local distro="$3"
  cat <<==EOTFVAR > ${virtualization}_vars.tfvars
ssh_user = "${vmuser}"
ssh_password = "${SSH_PASSWORD}"
vm_clone = "t-${distro}"
vm_name = "${vmname}"
vm_desc = "${vmdesc}"
cpu_sockets = 2
cpu_cores = 4
memory = 32768
==EOTFVAR
  # PM_NODE can be a comma-separated list of proxmox nodes
  # one of them will be selected by chance.
  PM_NODE=${PM_NODE// /}
  if [[ "${PM_NODE}" =~ , ]]; then
    IFS="," read -a nodes <<< ${PM_NODE}
    declare -p nodes;
    PM_NODE=${nodes[$(shuf -n 1 -i 0-$(("${#nodes[@]}" -1)))]}
  fi
  cat <<==EOTFVAR >> ${virtualization}_vars.tfvars
target_node = "${PM_NODE}"
==EOTFVAR
} 

setup_tfvars_hcloud() {
  local vmname="$1"
  local vmdesc="$2"
  local distro="$3"
  cat <<==EOTFVAR > ${virtualization}_vars.tfvars
vm_name = "${vmname}"
owner = "${INSTANCE_OWNER}"
ssh_user = "${vmuser}"
ssh_password = "${SSH_PASSWORD}"
image = "${distro}"
instance_type = "${HCLOUD_INSTANCE_TYPE}"
==EOTFVAR
  if [[ -n "$HCLOUD_PRIVATE_NETWORK ]]; then
    cat <<==EOTFVAR >> ${virtualization}_vars.tfvars
private_network = "${HCLOUD_PRIVATE_NETWORK}"
==EOTFVAR
  fi
}


setup_tfvars_aws() {
  local vmname="$1"
  local vmdesc="$2"
  local distro="$3"
  local ami
  local vmuser
  read ami vmuser < <(image_for_distro_aws ${distro})
  cat <<==EOTFVAR > ${virtualization}_vars.tfvars
vm_name = "${vmname}"
owner = "${INSTANCE_OWNER}"
ssh_user = "${vmuser}"
ssh_password = "${SSH_PASSWORD}"
instance_ami = "${ami}"
instance_type = "${AWS_INSTANCE_TYPE}"
==EOTFVAR
}

image_for_distro_aws() {
  local distro="$1"
  if [[ $distro =~ ^ami ]]; then
    ami=$distro
    vmuser=packer
  elif [ $distro == "ubuntu-18.04" ]; then
    ami="ami-078c9293d235c21bd" # packer
    vmuser=packer
    vmuser=ubuntu
  elif [ $distro == "centos-7.7" ]; then
    ami="ami-032a964267f9c476e" # packer
    vmuser=packer
    vmuser=centos
  elif [ $distro == "debian-9.13" ]; then
    ami="ami-0f72358adaffcfacf"
    vmuser=packer
  elif [ $distro == "debian-10.10" ]; then
    ami="ami-084bc6192f5170801" # aws
    vmuser=admin
    ami="ami-" # packer ! ClientError: Unsupported kernel version
    ami="ami-07e1f53ecf0301ee5" # packer 8gb
    vmuser=packer
  fi
  echo "${ami}" "${vmuser}"
}


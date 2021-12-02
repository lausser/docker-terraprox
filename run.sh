#! /bin/bash

set -x
. ./functions.sh

HCLOUD_INSTANCE_TYPE=${HCLOUD_INSTANCE_TYPE:-cx21}
AWS_INSTANCE_TYPE=${AWS_INSTANCE_TYPE:-t2.medium}
INSTANCE_OWNER=${INSTANCE_OWNER:-build}

main() {
  echo image version is $(<VERSION)
  virtualization=${VIRTUALIZATION:-proxmox}
  distro=${DISTRIBUTION:-centos-7.7}
  # this tag is used to make the vm name unique
  if [[ -z "${UNIQUE_TAG}" ]]; then
    uuid=$(uuidgen)
    uuid=${uuid%%-*}
  else
    uuid=${UNIQUE_TAG##*-}
  fi
  UNIQUE_TAG=${uuid}
  # the name of the vm, may be derived from uuid
  if [[ -z "${VM_NAME}" ]]; then
    vmname="b-${uuid}"
  else
    vmname=${VM_NAME}
  fi
  if [[ -z "$VM_DESC" ]]; then
    # a short description of the vm
    vmdesc="${distro} in workflow ${uuid}"
  else
    vmdesc=${VM_DESC}
  fi
  vmuser="packer"

  create_ssh_key

  check_environment ${virtualization}
  setup_tf_files ${virtualization}
  ls *.tf
  cat *.tf
  setup_tfvars ${virtualization} "${vmname}" "${vmdesc}" "${distro}"

  terraformrc=0
  run_terraform_init
  terraformrc=$?

  if [[ "$1" == "shell" ]]; then
    bash
  elif [[ "$1" == "passthrough" ]]; then
    terraform $*
    terraformrc=$?
  elif [[ "$1" == "apply" ]]; then
    run_terraform_apply ${virtualization}
    terraformrc=$?
  elif [[ "$1" == "destroy" ]]; then
    run_terraform_destroy ${virtualization}
    terraformrc=$?
  elif [[ "$1"  == "cleanup" ]]; then
    if [[ -n "${CONSUL_ADDRESS}" ]]; then
      # terraform destroy does not remove the key but leaves an empty hash
      rm -r consul_backend.tf
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
  
  exit $terraformrc
}

main "$@"; exit

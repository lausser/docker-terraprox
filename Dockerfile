ARG SSH_PASSPHRASE=geheim
FROM hashicorp/terraform:1.1.3

RUN apk add --no-cache make musl-dev go rsync shadow python3
RUN apk add --no-cache bash python3-dev
RUN apk add --no-cache patch
RUN apk add --no-cache ansible
RUN apk add --no-cache sshpass
RUN apk add --no-cache util-linux
RUN apk add --no-cache curl
RUN apk add --no-cache py3-pip
RUN pip3 install ruamel.yaml
RUN groupadd -r terraform -g 9901 && useradd -u 9901 --no-log-init -m -r -g terraform terraform

WORKDIR /root
ENV GOPROXY=https://goproxy.io,direct
ENV GO111MODULE=on
RUN go clean -modcache

RUN echo terraform-provider-proxmox 72c6277 = release 2.9.4
RUN echo terraform-provider-proxmox@v2.9.4 geht nicht, weil go = dreck
RUN go install github.com/Telmate/terraform-provider-proxmox@72c6277
RUN cp go/bin/terraform-provider-proxmox /usr/local/bin

RUN go get github.com/hetznercloud/terraform-provider-hcloud@v1.32.2
RUN cp go/bin/terraform-provider-hcloud /usr/local/bin

RUN rm -rf go

USER terraform
WORKDIR /home/terraform
RUN mkdir -p ./usr/share/terraform/plugins/terraform.local/local/proxmox/2.9.4/linux_amd64 && \
    cp /usr/local/bin/terraform-provider-proxmox ./usr/share/terraform/plugins/terraform.local/local/proxmox/2.9.4/linux_amd64/
# no proxmox provisioner needed for cloud-init
RUN mkdir -p ./usr/share/terraform/plugins/terraform.local/local/hcloud/1.32.2/linux_amd64 && \
    cp /usr/local/bin/terraform-provider-hcloud ./usr/share/terraform/plugins/terraform.local/local/hcloud/1.32.2/linux_amd64/

USER root
COPY run.sh /home/terraform
COPY functions.sh /home/terraform
COPY proxmox/ /home/terraform/proxmox
COPY aws/ /home/terraform/aws
COPY hcloud/ /home/terraform/hcloud
COPY ansible/ /home/terraform/ansible
COPY consul/ /home/terraform/consul
COPY provision.tf /home/terraform
COPY .terraformrc /home/terraform
RUN chown -R terraform:terraform /home/terraform/*
RUN chmod 755 /home/terraform/run.sh
RUN chmod 755 /home/terraform/functions.sh
ADD VERSION .
COPY VERSION /home/terraform

USER terraform
ENV ANSIBLE_HOST_KEY_CHECKING=False
ENTRYPOINT ["/home/terraform/run.sh"]

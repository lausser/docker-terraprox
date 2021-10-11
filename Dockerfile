ARG SSH_PASSPHRASE=geheim
FROM hashicorp/terraform:1.0.8

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
ENV GO111MODULE=auto
ENV GOPROXY=https://goproxy.io,direct

#RUN echo proxmox-api-go 5b9c621ea0cd5b401c7ddcaff659e47add27772e
#RUN go get github.com/Telmate/proxmox-api-go && \
#    go install github.com/Telmate/proxmox-api-go && \
#    cp go/bin/proxmox-api-go /usr/local/bin

ENV GO111MODULE=on
RUN echo terraform-provider-proxmox 0d6e7d75f4086f54575473d705cbc01853ee21a7
RUN go get github.com/Telmate/terraform-provider-proxmox
RUN cp go/bin/terraform-provider-proxmox /usr/local/bin

RUN go get github.com/hetznercloud/terraform-provider-hcloud@v1.31.1
RUN cp go/bin/terraform-provider-hcloud /usr/local/bin

RUN rm -rf go

USER terraform
WORKDIR /home/terraform
RUN mkdir -p ./usr/share/terraform/plugins/terraform.local/local/proxmox/1.0.0/linux_amd64 && \
    cp /usr/local/bin/terraform-provider-proxmox ./usr/share/terraform/plugins/terraform.local/local/proxmox/1.0.0/linux_amd64/
# no proxmox provisioner needed for cloud-init
RUN mkdir -p ./usr/share/terraform/plugins/terraform.local/local/hcloud/1.31.1/linux_amd64 && \
    cp /usr/local/bin/terraform-provider-hcloud ./usr/share/terraform/plugins/terraform.local/local/hcloud/1.31.1/linux_amd64/

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

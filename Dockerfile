FROM alpine:3.18

LABEL maintainer="NexOps"
LABEL anisble.version="core 2.14.5"
LABEL python3.version="3.11.8"
LABEL alpine.version="3.18"
LABEL packer.version="v1.10.2"

ENV PYTHONUNBUFFERED=1

CMD ["/bin/sh"]

RUN apk update && apk add --no-cache --upgrade krb5-dev krb5 build-base \
    subversion libcurl curl-dev ansible python3 python3-dev py3-pip openssh sshpass

RUN pip3 install --upgrade pip && pip3 install ncclient paramiko pykerberos \
    pyOpenSSL pypsrp pywinrm toml pexpect>=4.5 python-daemon pyyaml six \
    cryptography==3.4.8 jinja2==3.1.2 jmespath==1.0.1 MarkupSafe==2.1.2 \
    netaddr==0.8.0 pbr==5.11.1 ruamel.yaml ruamel.yaml.clib

#########################################################

ENV PACKER_VERSION=1.10.2
ENV PACKER_SHA256SUM=6ed412d212e6948f956a92099d6f941ddb470ff30ab40432622f5e68d594ec46

RUN apk add --no-cache git bash wget openssl gnupg xorriso

ADD https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip ./
ADD https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS ./

RUN sed -i '/.*linux_amd64.zip/!d' packer_${PACKER_VERSION}_SHA256SUMS
RUN sha256sum -cs packer_${PACKER_VERSION}_SHA256SUMS
RUN unzip packer_${PACKER_VERSION}_linux_amd64.zip -d /bin
RUN rm -f packer_${PACKER_VERSION}_linux_amd64.zip

#########################################################

RUN adduser -D builder
USER builder


# ENTRYPOINT ["/bin/packer"]
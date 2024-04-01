FROM quay.io/kubespray/kubespray:v2.23.0

LABEL maintainer="NexOps"
LABEL anisble.version="core 2.14.6"
LABEL python.version="3.10.12"
LABEL os.version="Ubuntu 22.04.2 LTS"
LABEL packer.version="v1.10.2"

#########################################################

ENV PACKER_VERSION=1.10.2
ENV PACKER_SHA256SUM=6ed412d212e6948f956a92099d6f941ddb470ff30ab40432622f5e68d594ec46

RUN apt update && apt install -y unzip git wget gnupg xorriso

ADD https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip ./
ADD https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS ./

RUN sed -i '/.*linux_amd64.zip/!d' packer_${PACKER_VERSION}_SHA256SUMS
RUN sha256sum -c packer_${PACKER_VERSION}_SHA256SUMS
RUN unzip packer_${PACKER_VERSION}_linux_amd64.zip -d /bin
RUN rm -f packer_${PACKER_VERSION}_linux_amd64.zip

#########################################################

RUN adduser --disabled-password --gecos "" builder
USER builder

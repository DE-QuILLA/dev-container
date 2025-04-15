FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV KUBECTL_VERSION=v1.31.0
ENV TERRAFORM_VERSION=1.11.3
ENV HELM_VERSION=3.16.4

# Prerequisite
RUN apt update && apt install -y \
    apt-transport-https \
    ca-certificates \
    gnupg \
    curl

# CLI setup
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt update -y \
    && apt install google-cloud-sdk -y
    
# Files transfer
COPY . /app
WORKDIR /app

# gcloud setup
RUN apt install google-cloud-cli-gke-gcloud-auth-plugin -y \
&& gcloud auth activate-service-account --key-file=key.json \
&& apt clean && rm -rf /var/lib/apt/lists/*
# The apt clean line must be the last of apt command

# Kubectl setup
RUN curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl \
    && gcloud container clusters get-credentials my-gke --region asia-northeast3 --project my-code-vocab
# maybe it's better to do this at runtime?

# Helm setup
RUN curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o helm.tar.gz \
    && tar -zxvf helm.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -rf helm.tar.gz linux-amd64

# Terraform setup
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Python packages
RUN pip install -r requirements-dev.txt && pre-commit install

# motd
RUN echo 'cat ./motd' >> /etc/bash.bashrc

# Default: allows for tidier commands
ENTRYPOINT [ "/bin/bash", "-c" ]
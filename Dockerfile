FROM python:3.11-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV KUBECTL_VERSION=v1.31.0
ENV TERRAFORM_VERSION=1.11.1
ENV HELM_VERSION=3.16.4

# Prerequisite
RUN apt update && apt install -y \
    apt-transport-https \
    ca-certificates \
    gnupg \
    curl \
    unzip \
    git

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
&& gcloud auth activate-service-account --key-file=key.json 

# Kubectl setup
RUN curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl
# maybe it's better to do this at runtime?

# Helm setup
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt clean && rm -rf /var/lib/apt/lists/*
# The apt clean line must be the last of apt command

# Terraform setup
RUN curl -sSL -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Python packages
RUN pip install -r requirements-dev.txt

# motd
RUN echo 'cat ./motd' >> /etc/bash.bashrc \
    && echo 'alias my-gke="gcloud container clusters get-credentials my-gke --region asia-northeast3 --project my-code-vocab"' >> /etc/bash.bashrc

# Default: allows for tidier commands
ENTRYPOINT [ "/bin/bash", "-c" ]
CMD [ "Use command or /bin/bash for an interactive session, otherwise it will terminate immedietamente" ]
FROM python:3.11-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV KUBECTL_VERSION=v1.31.0
ENV TERRAFORM_VERSION=1.11.1
ENV HELM_VERSION=3.16.4

# Non root sudo
ARG USER
ARG USER_UID
ARG USER_GID
RUN getent group ${USER_GID} || groupadd --gid ${USER_GID} ${USER} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USER}

# Prerequisite
RUN apt-get update && apt-get install -y \
    apt-transport-https ca-certificates \
    gnupg nano curl unzip git tar

# CLI setup
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update -y \
    && apt-get install google-cloud-sdk -y
    
# Files transfer
COPY ./key.json /app/key.json
COPY ./motd.sh /etc/profile.d/motd.sh
COPY ./requirements-dev.txt /app/requirements-dev.txt
WORKDIR /app

# gcloud setup
RUN apt-get install google-cloud-cli-gke-gcloud-auth-plugin -y

# Kubectl setup
RUN curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Helm setup
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update && apt-get install -y helm \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# The apt clean line must be the last of apt command

# Terraform setup
RUN curl -sSL -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# kubeval (kubeconform) setup
RUN curl -Lo ./kubeconform-linux-amd64.tar.gz https://github.com/yannh/kubeconform/releases/download/v0.7.0/kubeconform-linux-amd64.tar.gz \
    && tar -xzf kubeconform-linux-amd64.tar.gz \
    && mv kubeconform /usr/local/bin/ \
    && rm kubeconform-linux-amd64.tar.gz

# Aliases
RUN echo 'source /etc/profile.d/motd.sh' >> /etc/bash.bashrc

# Python packages
RUN pip install -r requirements-dev.txt --no-cache-dir

# User specific
USER $USER
RUN gcloud auth activate-service-account --key-file=key.json \
    && sed -i 's/^#\s*\(force_color_prompt=yes\)/\1/' /home/${USER}/.bashrc
# ENV PATH="/home/$USER/.local/bin:$PATH"

# Default: allows for tidier commands
ENTRYPOINT [ "/bin/bash", "-c" ]

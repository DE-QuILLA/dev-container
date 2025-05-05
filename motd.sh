#!/bin/bash
gcloud --version
terraform --version
pre-commit --version
helm version
echo -e "\033[91m1. Provision your cluster\033[0m"
echo -e "\033[91m2. Use alias 'kinit' to fetch kube config!\033[0m"
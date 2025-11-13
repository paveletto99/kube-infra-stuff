# Use Debian as the base image
FROM mcr.microsoft.com/devcontainers/base:debian

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl git unzip wget python3-pip gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - \
    && echo "deb https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform

# Install TFLint
RUN curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Install Tfsec
RUN curl -fsSL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Install Checkov
RUN pip3 install checkov

# Install Trufflehog
RUN pip3 install trufflehog

# Install Lefthook
RUN curl -fsSL https://github.com/evilmartians/lefthook/releases/latest/download/lefthook-linux-amd64 -o /usr/local/bin/lefthook \
    && chmod +x /usr/local/bin/lefthook

# Install SOPS
RUN curl -fsSL https://github.com/getsops/sops/releases/latest/download/sops-linux-amd64 -o /usr/local/bin/sops \
    && chmod +x /usr/local/bin/sops

# Install Age (Alternative Encryption)
RUN curl -fsSL https://github.com/FiloSottile/age/releases/latest/download/age-linux-amd64 -o /usr/local/bin/age \
    && chmod +x /usr/local/bin/age

# Set user permissions
RUN useradd -m vscode && chown -R vscode:vscode /workspace
USER vscode
WORKDIR /workspace

# Install pre-commit
RUN pip3 install pre-commit && pre-commit install

# Install cilium CLI

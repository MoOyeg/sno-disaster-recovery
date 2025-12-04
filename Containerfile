FROM registry.access.redhat.com/ubi9/ubi:latest

# Install required packages
RUN dnf install -y \
    python3 \
    python3-pip \
    git \
    openssh-clients \
    podman \
    wget \
    iputils \
    && dnf clean all

# Install virtctl
RUN VIRTCTL_VERSION=$(wget -qO- https://api.github.com/repos/kubevirt/kubevirt/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && \
    wget -O /usr/local/bin/virtctl https://github.com/kubevirt/kubevirt/releases/download/${VIRTCTL_VERSION}/virtctl-${VIRTCTL_VERSION}-linux-amd64 && \
    chmod +x /usr/local/bin/virtctl

# Install Ansible and required Python packages
RUN pip3 install --no-cache-dir \
    ansible>=2.14 \
    kubernetes \
    openshift \
    requests \
    jinja2

# Install Ansible collections
RUN ansible-galaxy collection install \
    kubernetes.core \
    community.general \
    ansible.posix

# Create workspace directory
WORKDIR /workspace

# Set entrypoint
ENTRYPOINT ["ansible-playbook"]
CMD ["--version"]

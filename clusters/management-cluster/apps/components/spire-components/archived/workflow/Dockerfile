FROM debian:bullseye

RUN apt-get update && \
    apt-get install -y sudo curl wget jq gawk tar sed && \
    apt-get install -y gnupg2 apt-transport-https ca-certificates && \
    mkdir -p /etc/apt/keyrings/ && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \    
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl && \
    wget https://github.com/spiffe/spire/releases/download/v1.8.2/spire-1.8.2-linux-amd64-musl.tar.gz && \
    tar zvxf spire-1.8.2-linux-amd64-musl.tar.gz && \
    cp -r spire-1.8.2/. /opt/spire/

RUN ln -s /opt/spire/bin/spire-server /usr/bin/spire-server && \
    ln -s /opt/spire/bin/spire-agent /usr/bin/spire-agent
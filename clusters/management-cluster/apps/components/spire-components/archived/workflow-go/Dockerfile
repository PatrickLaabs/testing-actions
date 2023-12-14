# Stage 1: Build environment with Go and necessary tools
FROM golang:latest as builder

# Install necessary tools
RUN apt-get update && \
    apt-get install -y curl wget jq gawk tar sed gnupg2 apt-transport-https ca-certificates 

# Add Kubernetes repository and install kubectl
RUN mkdir -p /etc/apt/keyrings/ && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl

# Download and set up SPIRE
RUN wget https://github.com/spiffe/spire/releases/download/v1.8.2/spire-1.8.2-linux-amd64-musl.tar.gz -O /spire.tar.gz
RUN mkdir /spire
RUN tar -xzf /spire.tar.gz -C /spire

# Set up the Go environment
WORKDIR /app
COPY go.mod main.go ./
RUN go mod tidy
RUN go mod download
COPY . .

# Compile the Go program with static linking
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o secret-init .

# Stage 2: Create a minimal container from scratch
FROM scratch

# Copy the compiled Go binary
COPY --from=builder /app/secret-init /secret-init

# Copy necessary binaries and files from the builder stage
COPY --from=builder /usr/bin/kubectl /usr/bin/kubectl
COPY --from=builder /spire /opt/spire
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# # User management
# COPY <<EOF /etc/group
# root:x:0:
# nonroot-group:x:3000:
# EOF

# COPY <<EOF /etc/passwd
# root:x:0:0:root:/root:/sbin/nologin
# nonroot:x:2000:3000:nonroot:/app:/sbin/nologin
# EOF
# USER nonroot

# Set the entrypoint to your application
ENTRYPOINT ["/secret-init"]

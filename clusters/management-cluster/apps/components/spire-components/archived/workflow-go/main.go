package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
)

func main() {
	defer cleanup()

	token, err := fetchToken("TESTING", "/run/spire/sockets/agent.sock")
	if err != nil {
		log.Fatalf("Failed to fetch token: %v", err)
	}

	payload := fmt.Sprintf("{\"role\": \"dev\",\"jwt\": \"%s\"}", token)
	err = os.WriteFile("payload.json", []byte(payload), 0644)
	if err != nil {
		log.Fatalf("Failed to write payload.json: %v", err)
	}

	response, err := curlPost("http://vault.vault.svc.cluster.local:8200/v1/auth/jwt/login", "payload.json")
	if err != nil {
		log.Fatalf("Failed to send request to Vault: %v", err)
	}

	clientToken, err := extractJSONField(response, "auth.client_token")
	if err != nil {
		log.Fatalf("Failed to extract client token: %v", err)
	}

	err = os.WriteFile("secret-data.env", []byte(fmt.Sprintf("token=%s", clientToken)), 0644)
	if err != nil {
		log.Fatalf("Failed to write secret-data.env: %v", err)
	}

	err = createK8sSecret("secret-data.env", "vault-test")
	if err != nil {
		log.Fatalf("Failed to create Kubernetes secret: %v", err)
	}
}

func fetchToken(audience, socketPath string) (string, error) {
	cmd := exec.Command("/opt/spire/bin/spire-agent", "api", "fetch", "jwt", "-audience", audience, "-socketPath", socketPath)
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "token(spiffe://") {
			return strings.TrimSpace(strings.SplitN(line, " ", 2)[1]), nil
		}
	}
	return "", fmt.Errorf("token not found in output")
}

func curlPost(url, dataFile string) (string, error) {
	cmd := exec.Command("curl", "-s", "--request", "POST", "--data", "@"+dataFile, url)
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(output), nil
}

func extractJSONField(jsonStr, field string) (string, error) {
	cmd := exec.Command("jq", "-r", fmt.Sprintf(".%s", field))
	cmd.Stdin = strings.NewReader(jsonStr)
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func createK8sSecret(envFile, secretName string) error {
	cmd := exec.Command("kubectl", "create", "secret", "generic", secretName, "--from-env-file="+envFile)
	_, err := cmd.Output()
	return err
}

func cleanup() {
	os.Remove("secret-data.env")
	os.Remove("payload.json")
}

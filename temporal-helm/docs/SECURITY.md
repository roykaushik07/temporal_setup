# Temporal Security & Access Control

This guide explains how to secure your Temporal deployment with authentication and access control.

## Table of Contents

- [Overview](#overview)
- [Type 1: UI Access Control](#type-1-ui-access-control)
  - [Option A: Basic Authentication](#option-a-basic-authentication)
  - [Option B: OAuth/OIDC](#option-b-oauthoidc)
  - [Option C: LDAP/Active Directory](#option-c-ldapactive-directory)
- [Type 2: Server Access Control](#type-2-server-access-control)
  - [Option A: Namespace Isolation](#option-a-namespace-isolation)
  - [Option B: Mutual TLS (mTLS)](#option-b-mutual-tls-mtls)
- [Combined Security Configurations](#combined-security-configurations)
- [Troubleshooting](#troubleshooting)

---

## Overview

Temporal provides two types of access control:

1. **UI Access Control** - Controls who can view and interact with the Temporal Web UI
2. **Server Access Control** - Controls which workers/clients can connect to Temporal server

**All security features are OPTIONAL and DISABLED by default.** Enable only what you need.

---

## Type 1: UI Access Control

Controls who can access the Temporal Web UI at port 8080.

### Option A: Basic Authentication

**Best for**: Internal tools, dev/staging environments
**Pros**: Simple to set up, no external dependencies
**Cons**: Not suitable for large teams, no SSO integration

#### Setup Steps

1. **Install htpasswd** (if not already installed):
   ```bash
   # macOS
   brew install httpd

   # Ubuntu/Debian
   sudo apt-get install apache2-utils
   ```

2. **Create password file**:
   ```bash
   # Create password for user 'admin'
   htpasswd -c auth admin
   # Enter password when prompted

   # Add more users (without -c flag)
   htpasswd auth user2
   ```

3. **Create Kubernetes secret**:
   ```bash
   kubectl create secret generic temporal-ui-basic-auth \
     --from-file=auth=auth \
     -n temporal
   ```

4. **Update values.yaml**:
   ```yaml
   security:
     ui:
       authentication:
         enabled: true
         basicAuth:
           enabled: true
           existingSecret: "temporal-ui-basic-auth"
           secretKey: "auth"

   ui:
     ingress:
       enabled: true
       className: "nginx"
       hosts:
         - host: temporal-ui.yourcompany.com
           paths:
             - path: /
               pathType: Prefix
   ```

5. **Deploy**:
   ```bash
   helm upgrade temporal ./temporal-helm -f values-production.yaml
   ```

6. **Access UI**:
   - Navigate to `https://temporal-ui.yourcompany.com`
   - Enter username and password when prompted

---

### Option B: OAuth/OIDC

**Best for**: Production environments with corporate SSO
**Pros**: Integrates with existing identity providers, secure
**Cons**: Requires oauth2-proxy deployment, more complex setup

#### Prerequisites

- Corporate SSO provider (Okta, Azure AD, Google Workspace, etc.)
- oauth2-proxy installed in cluster

#### Setup Steps

1. **Deploy oauth2-proxy**:
   ```bash
   # Using HELM
   helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
   helm install oauth2-proxy oauth2-proxy/oauth2-proxy \
     --namespace temporal \
     --set config.clientID=<your-client-id> \
     --set config.clientSecret=<your-client-secret> \
     --set config.cookieSecret=$(openssl rand -base64 32) \
     --set config.configFile.provider=oidc \
     --set config.configFile.oidcIssuerUrl=https://login.microsoftonline.com/<tenant-id>/v2.0 \
     --set config.configFile.emailDomains[0]="yourcompany.com"
   ```

2. **Create OAuth secret**:
   ```bash
   kubectl create secret generic temporal-oauth \
     --from-literal=client-id=<your-client-id> \
     --from-literal=client-secret=<your-client-secret> \
     --from-literal=cookie-secret=$(openssl rand -base64 32) \
     -n temporal
   ```

3. **Update values.yaml**:
   ```yaml
   security:
     ui:
       authentication:
         enabled: true
         oauth:
           enabled: true
           provider: "oidc"
           issuerUrl: "https://login.microsoftonline.com/<tenant-id>/v2.0"
           clientId: "<your-client-id>"
           existingSecret: "temporal-oauth"
           emailDomains:
             - yourcompany.com

   ui:
     ingress:
       enabled: true
       className: "nginx"
       hosts:
         - host: temporal-ui.yourcompany.com
           paths:
             - path: /
               pathType: Prefix
   ```

4. **Deploy**:
   ```bash
   helm upgrade temporal ./temporal-helm -f values-production.yaml
   ```

5. **Access UI**:
   - Navigate to `https://temporal-ui.yourcompany.com`
   - Redirected to corporate login page
   - After authentication, redirected back to Temporal UI

---

### Option C: LDAP/Active Directory

**Best for**: Environments with existing LDAP/AD infrastructure
**Pros**: Direct integration with corporate directory
**Cons**: Temporal UI has limited LDAP support, configuration varies by UI version

#### Setup Steps

1. **Create LDAP service account** in Active Directory:
   - Example: `cn=temporal-svc,ou=serviceaccounts,dc=yourcompany,dc=com`
   - Grant read permissions for user searches

2. **Create Kubernetes secret**:
   ```bash
   kubectl create secret generic temporal-ldap \
     --from-literal=bind-password=<service-account-password> \
     -n temporal
   ```

3. **Update values.yaml**:
   ```yaml
   security:
     ui:
       authentication:
         enabled: true
         ldap:
           enabled: true
           host: "ldap.yourcompany.com"
           port: 389
           useTLS: true
           baseDN: "dc=yourcompany,dc=com"
           bindDN: "cn=temporal-svc,ou=serviceaccounts,dc=yourcompany,dc=com"
           userSearchBase: "ou=users,dc=yourcompany,dc=com"
           userSearchFilter: "(&(objectClass=user)(sAMAccountName={0}))"
           existingSecret: "temporal-ldap"
   ```

4. **Deploy**:
   ```bash
   helm upgrade temporal ./temporal-helm -f values-production.yaml
   ```

5. **Access UI**:
   - Navigate to Temporal UI
   - Enter Active Directory username and password

**Note**: LDAP support in Temporal UI is experimental. For production, consider using Basic Auth or OAuth at Ingress level.

---

## Type 2: Server Access Control

Controls which workers and clients can connect to Temporal server on port 7233.

### Option A: Namespace Isolation

**Best for**: Starting out, multi-tenant environments
**Pros**: Zero overhead, built into Temporal, easy to manage
**Cons**: Logical separation only (not true authentication)

#### How It Works

- Each team/application gets their own namespace
- Workers must specify namespace when connecting
- Workflows in one namespace cannot see workflows in another

#### Setup Steps

1. **Enable in values.yaml** (enabled by default):
   ```yaml
   security:
     server:
       authentication:
         enabled: false  # No authentication needed
         namespaceIsolation:
           enabled: true  # Always available
   ```

2. **Create namespaces**:
   ```bash
   # Get temporal server pod name
   TEMPORAL_POD=$(kubectl get pod -n temporal -l app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}')

   # Create namespaces
   kubectl exec -it $TEMPORAL_POD -n temporal -- tctl namespace register team-a
   kubectl exec -it $TEMPORAL_POD -n temporal -- tctl namespace register team-b
   kubectl exec -it $TEMPORAL_POD -n temporal -- tctl namespace register team-c
   ```

3. **Workers specify namespace**:
   ```python
   # Team A worker
   from temporalio.client import Client

   async def main():
       client = await Client.connect(
           "temporal-server.temporal.svc.cluster.local:7233",
           namespace="team-a"
       )

       worker = Worker(
           client,
           task_queue="team-a-queue",
           workflows=[MyWorkflow],
           activities=[my_activity]
       )
       await worker.run()
   ```

4. **Start workflows in specific namespace**:
   ```python
   client = await Client.connect(
       "temporal-server.temporal.svc.cluster.local:7233",
       namespace="team-a"
   )

   handle = await client.start_workflow(
       MyWorkflow.run,
       id="workflow-1",
       task_queue="team-a-queue"
   )
   ```

#### Benefits

- **Isolation**: Team A cannot see or execute Team B's workflows
- **Organization**: Clear separation of concerns
- **Zero overhead**: No performance impact
- **Built-in**: No additional configuration needed

---

### Option B: Mutual TLS (mTLS)

**Best for**: Production environments with strict security requirements
**Pros**: Strongest security, cryptographic authentication
**Cons**: Complex setup, certificate management overhead

#### How It Works

- Server and clients both present certificates
- Certificates signed by trusted Certificate Authority (CA)
- Both sides verify each other's identity

#### Setup Steps

##### 1. Generate Certificate Authority (CA)

```bash
# Generate CA private key
openssl genrsa -out ca.key 4096

# Generate CA certificate (valid 10 years)
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=Temporal CA"
```

##### 2. Generate Server Certificate

```bash
# Generate server private key
openssl genrsa -out server.key 2048

# Generate certificate signing request (CSR)
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=temporal-server.yourcompany.com"

# Sign with CA (valid 1 year)
openssl x509 -req -days 365 -in server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt
```

##### 3. Generate Client Certificates (for each worker)

```bash
# For Team A worker
openssl genrsa -out client-team-a.key 2048
openssl req -new -key client-team-a.key -out client-team-a.csr \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=team-a-worker"
openssl x509 -req -days 365 -in client-team-a.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out client-team-a.crt

# For Team B worker
openssl genrsa -out client-team-b.key 2048
openssl req -new -key client-team-b.key -out client-team-b.csr \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=team-b-worker"
openssl x509 -req -days 365 -in client-team-b.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out client-team-b.crt
```

##### 4. Create Kubernetes Secrets

```bash
# CA certificate
kubectl create secret generic temporal-ca \
  --from-file=ca.crt=ca.crt \
  -n temporal

# Server certificate
kubectl create secret tls temporal-server-tls \
  --cert=server.crt \
  --key=server.key \
  -n temporal
```

##### 5. Update values.yaml

```yaml
security:
  server:
    authentication:
      enabled: true
      mtls:
        enabled: true
        requireClientAuth: true
        ca:
          existingSecret: "temporal-ca"
        serverCert:
          existingSecret: "temporal-server-tls"
        frontend:
          serverName: "temporal-server.yourcompany.com"

server:
  service:
    type: LoadBalancer  # If workers are outside cluster
```

##### 6. Deploy

```bash
helm upgrade temporal ./temporal-helm -f values-production.yaml
```

##### 7. Workers Use Client Certificates

```python
from temporalio.client import Client, TLSConfig

async def main():
    # Load client certificate and key
    with open("client-team-a.crt", "rb") as f:
        client_cert = f.read()
    with open("client-team-a.key", "rb") as f:
        client_key = f.read()

    # Connect with mTLS
    client = await Client.connect(
        "temporal-server.yourcompany.com:7233",
        namespace="team-a",
        tls=TLSConfig(
            client_cert=client_cert,
            client_private_key=client_key
        )
    )

    worker = Worker(
        client,
        task_queue="team-a-queue",
        workflows=[MyWorkflow],
        activities=[my_activity]
    )
    await worker.run()
```

---

## Combined Security Configurations

You can combine multiple security features for defense-in-depth.

### Example 1: Basic Auth + Namespace Isolation

**Use case**: Internal tool with simple auth, multiple teams

```yaml
security:
  ui:
    authentication:
      enabled: true
      basicAuth:
        enabled: true
        existingSecret: "temporal-ui-basic-auth"

  server:
    authentication:
      enabled: false
      namespaceIsolation:
        enabled: true
```

### Example 2: OAuth + mTLS

**Use case**: Production with SSO and strong worker authentication

```yaml
security:
  ui:
    authentication:
      enabled: true
      oauth:
        enabled: true
        provider: "oidc"
        issuerUrl: "https://login.microsoftonline.com/<tenant-id>/v2.0"
        clientId: "<client-id>"
        existingSecret: "temporal-oauth"

  server:
    authentication:
      enabled: true
      namespaceIsolation:
        enabled: true
      mtls:
        enabled: true
        requireClientAuth: true
        ca:
          existingSecret: "temporal-ca"
        serverCert:
          existingSecret: "temporal-server-tls"
        frontend:
          serverName: "temporal-server.yourcompany.com"
```

---

## Troubleshooting

### UI Authentication Issues

**Problem**: "403 Forbidden" when accessing UI with Basic Auth

**Solution**:
- Verify secret exists: `kubectl get secret temporal-ui-basic-auth -n temporal`
- Check ingress annotations: `kubectl describe ingress temporal-ui -n temporal`
- Verify nginx ingress controller is running

---

**Problem**: OAuth redirect fails

**Solution**:
- Verify oauth2-proxy is running: `kubectl get pods -n temporal | grep oauth2-proxy`
- Check oauth2-proxy logs: `kubectl logs -n temporal <oauth2-proxy-pod>`
- Verify callback URL is registered with OAuth provider
- Check client ID and secret are correct

---

**Problem**: LDAP authentication fails

**Solution**:
- Verify LDAP server is reachable from cluster
- Test LDAP bind: `ldapsearch -x -H ldap://ldap.yourcompany.com -D "cn=..." -W -b "dc=..."`
- Check UI logs: `kubectl logs -n temporal <temporal-ui-pod>`
- Verify user search filter matches your AD schema

---

### Server mTLS Issues

**Problem**: Workers cannot connect with "certificate verify failed"

**Solution**:
- Verify CA certificate is correct
- Check server certificate CN matches server hostname
- Ensure client certificate is signed by same CA
- Verify certificates haven't expired: `openssl x509 -in server.crt -noout -dates`

---

**Problem**: "RequireAndVerifyClientCert" but client has no cert

**Solution**:
- Verify client certificate and key are loaded in worker code
- Check certificate format (PEM encoding)
- Ensure private key matches certificate

---

### Namespace Issues

**Problem**: Workers cannot start workflows

**Solution**:
- Verify namespace exists: `kubectl exec -it <temporal-pod> -n temporal -- tctl namespace list`
- Check worker is connecting to correct namespace
- Verify namespace is active (not archived)

---

## Security Best Practices

1. **Start Simple**: Begin with namespace isolation, add authentication later
2. **Use Secrets**: Never hardcode passwords in values.yaml
3. **Enable TLS**: Always use TLS for external connections
4. **Rotate Certificates**: Set expiration dates and rotate before expiry
5. **Principle of Least Privilege**: Give workers access only to their namespace
6. **Audit Logs**: Monitor authentication failures and unauthorized access attempts
7. **Network Policies**: Use Kubernetes NetworkPolicies to restrict pod-to-pod communication

---

## Additional Resources

- [Temporal Security Documentation](https://docs.temporal.io/security)
- [nginx Ingress Authentication](https://kubernetes.github.io/ingress-nginx/examples/auth/)
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [OpenSSL Certificate Generation](https://www.openssl.org/docs/man1.1.1/man1/openssl-req.html)

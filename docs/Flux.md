# Create Source for Private GitHub Repository

Check out the installations instruction in the [Flux Documentation](https://fluxcd.io/flux/get-started/).

## Create Secret

Create an SSH key for Flux and add it to GitHub as a deployment key.
```shell
# create an ssh key
ssh-keygen -t ed25519 -C "fluxcd@staging-cluster" -f ./identity_file
```

Next, add the SSH key as a Kubernetes Secret in the flux namespace:

```shell
# create the secret in flux
flux create secret git flux-github-secret \
--url=ssh://git@github.com/terrameijar/homelab \
--private-key-file=./identity_file
```

## Reference the secret in the GitRepository

Create a new Git source and add a reference to the secret:

```shell
flux create source git podinfo \
	--url=https://github.com/stefanprodan/podinfo \
	--branch=master \
	--interval=1m \
	--export > ./clusters/my-cluster/podinfo-source.yaml
```

Add a reference to the secret:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: metallb
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  url: ssh://git@github.com/terrameijar/homelab.git
  secretRef:
    name: flux-github-secret
```

## Create Kustomization

Configure Flux to build and apply the podinfo manifests

```shell
flux create kustomization podinfo \
 --target-namespace=default \
 --source=podinfo \
 --path="./kustomize" \
 --prune=true \
 --wait=true \
 --interval=30m \
 --retry-interval=2m \
 --health-check-timeout=3m \
 --export >./clusters/my-cluster/podinfo-kustomization.yaml
```

Produces the following output:


```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 30m0s
  path: ./kustomize
  prune: true
  retryInterval: 2m0s
  sourceRef:
    kind: GitRepository
    name: podinfo
  targetNamespace: default
  timeout: 3m0s
  wait: true
```

Commit and push changes

## Watch changes

```shell
flux get kustomizations --watch
```
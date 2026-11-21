[Read this in Russian](README.ru.md)

# k3s-oci-lab

Terraform and Ansible for a single-node K3s lab on Oracle Cloud (OCI Always Free, ARM64).

This is a learning cluster: one node, no high availability, no production workloads. The code is extracted from a private infrastructure repo that manages the running VM; resource names were changed for this copy.

## What it builds

**Terraform** (`terraform/`), OCI provider `9.11.0`, local state:

- VCN `10.30.0.0/16`, public subnet, internet gateway and route table.
- A dedicated security list instead of the VCN default: SSH only from the operator's `/32`, ICMP type 3 code 4 for path MTU discovery, all outbound. The K3s API (6443) has no public ingress.
- VM `VM.Standard.A1.Flex`, 1 OCPU, 8 GB RAM, 50 GB boot volume, Ubuntu 24.04 aarch64. `prevent_destroy` guards it from accidental replacement.
- Input validation: region format, compartment and image OCIDs, `.pub` key path, `/32` operator CIDR.

**Ansible** (`ansible/site.yml`), idempotent:

1. Asserts Ubuntu on aarch64.
2. Installs `ca-certificates` and `iptables`.
3. Downloads the pinned K3s binary (`v1.37.1+k3s1`) and checks its SHA-256.
4. Installs a systemd unit for `k3s server` with Traefik and ServiceLB disabled.
5. Starts the service, waits for the kubeconfig, node `Ready` and the CoreDNS rollout.

The cluster runs CoreDNS, local-path-provisioner and metrics-server. There are no applications in it yet.

## Usage

Requirements: Terraform `>= 1.7`, an OCI API key profile in `~/.oci/config`, Ansible on the control machine.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in OCIDs, key path, your IP/32
terraform init -lockfile=readonly
terraform plan -out=lab.tfplan                  # read the plan, reject any "must be replaced"
terraform apply lab.tfplan
terraform output -raw public_ip

cd ../ansible
cp inventory.ini.example inventory.ini          # put the public IP and key path here
ansible-playbook site.yml
```

Check the node on the VM: `sudo k3s kubectl get nodes -o wide`.

## Access to the API

Port 6443 is closed in OCI, so use an SSH tunnel:

```bash
ssh -i ~/.ssh/YOUR_KEY -N -L 6443:127.0.0.1:6443 ubuntu@<public_ip>
```

Copy `/etc/rancher/k3s/k3s.yaml` from the VM to a private path outside the repo, set `server: https://127.0.0.1:6443`, `chmod 600` it and run `KUBECONFIG=<path> kubectl get nodes`. The file gives cluster-admin rights, treat it as a secret.

## Notes

- `terraform.tfvars`, state and plans are in `.gitignore`. Back up the local state after each apply and keep an encrypted copy elsewhere.
- Changing the operator IP means editing `ssh_source_cidr` and running plan/apply again.
- State backups do not contain Kubernetes data.
- CI runs `terraform fmt`/`validate`, `ansible-playbook --syntax-check` and `ansible-lint`. It does not touch the cloud.

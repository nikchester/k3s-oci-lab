[Read this in English](README.md)

# k3s-oci-lab

Terraform и Ansible для учебного K3s-кластера на одном узле в Oracle Cloud (OCI Always Free, ARM64).

Это учебный стенд: один узел, без высокой доступности и продакшен-нагрузки. Код вынесен из приватного инфраструктурного репозитория, которым управляется работающая VM. Имена ресурсов в этой копии изменены.

## Что создаётся

**Terraform** (`terraform/`), провайдер OCI `9.11.0`, локальный state:

- VCN `10.30.0.0/16`, публичная подсеть, internet gateway и таблица маршрутов.
- Свой security list вместо дефолтного: SSH только с `/32` оператора, ICMP type 3 code 4 для path MTU discovery, весь исходящий трафик. У API K3s (6443) публичного доступа нет.
- VM `VM.Standard.A1.Flex`, 1 OCPU, 8 GB RAM, диск 50 GB, Ubuntu 24.04 aarch64. `prevent_destroy` защищает от случайного пересоздания.
- Проверки входных данных: формат региона, OCID compartment и образа, путь к `.pub`-ключу, CIDR оператора только `/32`.

**Ansible** (`ansible/site.yml`), идемпотентный:

1. Проверяет, что хост Ubuntu на aarch64.
2. Ставит `ca-certificates` и `iptables`.
3. Скачивает зафиксированный бинарник K3s (`v1.37.1+k3s1`) и сверяет SHA-256.
4. Ставит systemd-юнит `k3s server` с выключенными Traefik и ServiceLB.
5. Запускает службу, ждёт kubeconfig, статус узла `Ready` и rollout CoreDNS.

В кластере работают CoreDNS, local-path-provisioner и metrics-server. Приложений пока нет.

## Запуск

Нужны Terraform `>= 1.7`, профиль API-ключа OCI в `~/.oci/config` и Ansible на управляющей машине.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # заполнить OCID, путь к ключу, свой IP/32
terraform init -lockfile=readonly
terraform plan -out=lab.tfplan                  # прочитать план, отклонить любой "must be replaced"
terraform apply lab.tfplan
terraform output -raw public_ip

cd ../ansible
cp inventory.ini.example inventory.ini          # вписать публичный IP и путь к ключу
ansible-playbook site.yml
```

Проверка на VM: `sudo k3s kubectl get nodes -o wide`.

## Доступ к API

Порт 6443 в OCI закрыт, поэтому через SSH-туннель:

```bash
ssh -i ~/.ssh/YOUR_KEY -N -L 6443:127.0.0.1:6443 ubuntu@<public_ip>
```

Скопировать `/etc/rancher/k3s/k3s.yaml` с VM в приватный каталог вне репо, поставить `server: https://127.0.0.1:6443`, права `600` и выполнить `KUBECONFIG=<путь> kubectl get nodes`. Файл даёт права cluster-admin, хранить как секрет.

## Заметки

- `terraform.tfvars`, state и планы в `.gitignore`. После каждого apply делать копию локального state и хранить зашифрованную копию отдельно.
- При смене IP оператора поменять `ssh_source_cidr` и снова пройти plan/apply.
- Копия state не содержит данных Kubernetes.
- CI запускает `terraform fmt`/`validate`, `ansible-playbook --syntax-check` и `ansible-lint`. В облако CI не ходит.

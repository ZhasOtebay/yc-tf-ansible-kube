terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.59.0"
    }
  }
}

provider "yandex" {
  token     = var.yandex_cloud_oauth_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
}

# Этап 1: Создание сети
resource "yandex_vpc_network" "lab_net" {
  name = "lab-network"
}

# Этап 2: Создание подсети
resource "yandex_vpc_subnet" "my_subnet" {
  name           = "my-subnet"
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.0.0.0/24"]  # Убедитесь, что этот диапазон не пересекается с другими подсетями
  network_id     = yandex_vpc_network.lab_net.id
}

# Этап 3: Создание группы безопасности
resource "yandex_vpc_security_group" "group1" {
  name        = "my-security-group"
  description = "Security group for Kubernetes nodes"
  network_id  = yandex_vpc_network.lab_net.id

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Этап 4: Создание внешних IP-адресов
resource "yandex_vpc_address" "external_ip" {
  count = 2
  name  = "k8s-node-${count.index + 1}"

  external_ipv4_address {
    zone_id = "ru-central1-a"  # Убедитесь, что этот аргумент указан правильно
  }
}

# Этап 5: Создание экземпляров виртуальных машин
data "yandex_compute_image" "ubuntu_image" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "k8s_nodes" {
  count       = 2
  name        = "k8s-node-${count.index + 1}"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores   = 4
    memory  = 8
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_image.id
      size = 28
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.my_subnet.id
    security_group_ids = [yandex_vpc_security_group.group1.id]
    nat                = true
    nat_ip_address     = yandex_vpc_address.external_ip[count.index].external_ipv4_address[0].address
  }

  scheduling_policy {
    preemptible = false
  }

  metadata = {
    ssh-keys = "your-username:${var.ssh_public_key}"  # Замените на ваше имя пользователя
  }
}

# Вывод публичных IP адресов
output "public_ips" {
  value = [for addr in yandex_vpc_address.external_ip : addr.external_ipv4_address[0].address]
}


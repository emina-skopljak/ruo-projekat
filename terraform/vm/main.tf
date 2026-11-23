###############################################################################
# AO-3: virtuelnu masinu i njenu mrezu kreira Terraform.
#
# Redoslijed koji Terraform sam izvodi:
#   1. storage pool + volumen iz cloud slike + overlay disk
#   2. libvirt mreza (NAT) sa DHCP rezervacijom za nasu MAC adresu
#   3. cloud-init seed (ISO sa user-data i meta-data)
#   4. domena (VM) koja sve to koristi
###############################################################################

locals {
  image_path      = pathexpand(var.image_path)
  ssh_public_key  = trimspace(file(pathexpand(var.ssh_public_key_path)))
  ssh_private_key = pathexpand(var.ssh_private_key_path)
  disk_size_bytes = var.disk_size_gb * 1024 * 1024 * 1024

  network_prefix  = tonumber(split("/", var.network_cidr)[1])
  network_gateway = cidrhost(var.network_cidr, 1)
}

# --- 1. storage ------------------------------------------------------------

resource "libvirt_pool" "ruo" {
  name = "ruo-pool"
  type = "dir"
  target {
    path = var.pool_path
  }
}

resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  target {
    path = "/var/lib/libvirt/images"
  }
}

# Bazna slika se uvozi u pool: od nje se pravi copy-on-write disk VM-a.
resource "libvirt_volume" "base" {
  name   = "${var.vm_name}-base.qcow2"
  pool   = libvirt_pool.ruo.name
  source = local.image_path
  format = "qcow2"
}

resource "libvirt_volume" "disk" {
  name           = "${var.vm_name}.qcow2"
  pool           = libvirt_pool.ruo.name
  base_volume_id = libvirt_volume.base.id
  format         = "qcow2"
  size           = local.disk_size_bytes
}

# --- 2. mreza --------------------------------------------------------------

# NAT mreza: VM izlazi na internet kroz host, a host joj pristupa direktno
# preko bridge adrese (192.168.100.1).
#
# Adresa VM-a NIJE iz DHCP pula, nego je staticka (vidi cloud-init/network-config.yaml).
# To je namjerno (DO-3): BIND zona mora imati stabilne A zapise, a DHCP bi ih
# mijenjao pri svakom podizanju. libvirt DHCP/dnsmasq i dalje radi, ali sluzi
# samo kao DNS forwarder do hosta dok BIND ne bude podignut.
resource "libvirt_network" "ruo" {
  name      = var.network_name
  mode      = "nat"
  bridge    = var.network_bridge
  addresses = [var.network_cidr]
  autostart = true

  dhcp {
    enabled = true
  }

  dns {
    enabled = true
  }
}

# --- 3. cloud-init ---------------------------------------------------------

# AO-4: pocetna konfiguracija VM-a ide kroz cloud-init. Skripte ne sadrze
# tajne: javni kljuc se cita iz ~/.ruo/ssh (van repoa), a privatni nikad ne
# napusta host.
resource "local_file" "user_data" {
  filename        = "${path.module}/.cloudinit-user-data.yaml"
  file_permission = "0644"
  content = templatefile("${path.module}/../../cloud-init/user-data.yaml", {
    hostname       = var.hostname
    domain         = var.domain
    admin_user     = var.admin_user
    ssh_public_key = local.ssh_public_key
  })
}

resource "local_file" "meta_data" {
  filename        = "${path.module}/.cloudinit-meta-data.yaml"
  file_permission = "0644"
  content = templatefile("${path.module}/../../cloud-init/meta-data.yaml", {
    hostname = var.hostname
    domain   = var.domain
    vm_ip    = var.vm_ip
  })
}

resource "local_file" "network_config" {
  filename        = "${path.module}/.cloudinit-network-config.yaml"
  file_permission = "0644"
  content = templatefile("${path.module}/../../cloud-init/network-config.yaml", {
    vm_mac          = var.vm_mac
    vm_ip           = var.vm_ip
    network_prefix  = local.network_prefix
    network_gateway = local.network_gateway
    domain          = var.domain
  })
}

resource "libvirt_cloudinit_disk" "seed" {
  name           = "${var.vm_name}-seed.iso"
  user_data      = local_file.user_data.content
  meta_data      = local_file.meta_data.content
  network_config = local_file.network_config.content
  depends_on     = [libvirt_pool.default]
}

# --- 4. domena (VM) --------------------------------------------------------

resource "libvirt_domain" "vm" {
  name      = var.vm_name
  memory    = var.memory_mb
  vcpu      = var.vcpu
  type      = "qemu"
  autostart = true
  cloudinit = libvirt_cloudinit_disk.seed.id

  cpu {
    mode = "host-model"
  }

  disk {
    volume_id = libvirt_volume.disk.id
  }

  network_interface {
    network_id = libvirt_network.ruo.id
    mac        = var.vm_mac
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

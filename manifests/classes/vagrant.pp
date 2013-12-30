class vagrant {
  # for some reason we need to run apt-get update before we can start. This
  # seems to be needed only for provisioning of VMs with Vagrant.
  exec { "apt-update":
    command => "/usr/bin/apt-get update"
  }
  Exec["apt-update"] -> Package <| |>
}
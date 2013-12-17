import 'classes/*.pp'

#include use_local_deb_mirror
#include use_nscl_deb_mirror

$archiver_nodes = [
  'archappl0.example.com',
  'archappl1.example.com',
  'archappl2.example.com',
]

node "archappl0.example.com" {
  include vagrant
  class { 'archiver_node':
    nodes_fqdn	=> $archiver_nodes,
  }
  Class['vagrant'] -> Class['archiver_node']
}

node "archappl1.example.com" {
  include vagrant
  class { 'archiver_node':
    nodes_fqdn	=> $archiver_nodes,
  }
  Class['vagrant'] -> Class['archiver_node']
}

node "archappl2.example.com" {
  include vagrant
  class { 'archiver_node':
    nodes_fqdn	=> $archiver_nodes,
  }
  Class['vagrant'] -> Class['archiver_node']
}
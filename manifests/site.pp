import 'classes/*.pp'

#include use_local_deb_mirror
#include use_nscl_deb_mirror
include apt

$archiver_nodes = [
  'archappl0.example.com',
  'archappl1.example.com',
  'archappl2.example.com',
]

$loadbalancer = 'loadbalancer.example.com'

$vcsbase = '/usr/local/lib/flint'
$iocbase = "${vcsbase}/flint-ca"

$archappl_tarball_url = 'http://downloads.sourceforge.net/project/epicsarchiverap/snapshots/archappl_v0.0.1_SNAPSHOT_25-June-2014T09-51-53.tar.gz'
$archappl_tarball_md5sum = '66bf5f5cce74dc1617adfd650c82760b'
$tomcatjdbc_tarball_url = 'http://people.apache.org/~fhanik/jdbc-pool/v1.1.0.1/apache-tomcat-jdbc-1.1.0.1-bin.tar.gz'
$tomcatjdbc_tarball_md5sum = '588c6fd5de5157780b1091a82cfbdd2d'

host { 'archappl0.example.com':
  ip           => '192.168.1.2',
  host_aliases => 'archappl0',
}

host { 'archappl1.example.com':
  ip           => '192.168.1.3',
  host_aliases => 'archappl1',
}

host { 'archappl2.example.com':
  ip           => '192.168.1.4',
  host_aliases => 'archappl2',
}

host { 'testioc.example.com':
  ip           => '192.168.1.5',
  host_aliases => 'testioc',
}

host { 'archiveviewer.example.com':
  ip           => '192.168.1.6',
  host_aliases => 'archiveviewer',
}

host { 'loadbalancer.example.com':
  ip           => '192.168.1.7',
  host_aliases => 'loadbalancer',
}

node /archappl[0-9]+.example.com/ {
  # RAM disk size should be 64 GB
  $desiredramdisksize = 64<<30

  # convert memory size from a string to bytes
  $mem = inline_template("<%
    mem,unit = scope.lookupvar('::memorysize').split
    mem = mem.to_f
    # Normalize mem to KiB
    case unit
      when nil
        mem *= (1<<0)
      when 'kB'
        mem *= (1<<10)
      when 'MB'
        mem *= (1<<20)
      when 'GB'
        mem *= (1<<30)
      when 'TB'
        mem *= (1<<40)
    end
  %><%= mem.to_i %>")

  # use a much smaller RAM disk of 100 MB if running in test invironment
  if 1.5 * $desiredramdisksize < $mem {
    $ramdisksize = $desiredramdisksize
  } else {
    warning('Requested RAM disk size is larger than two thirds of the total amount of RAM. Reducing size to 100 MB.')
    $ramdisksize = 100<<20
  }

  user { 'tomcat7':
    ensure => present,
  }

  file { '/srv/sts':
    ensure  => directory,
  }

  mount { '/srv/sts':
    ensure  => mounted,
    device  => 'tmpfs',
    fstype  => 'tmpfs',
    options => "defaults,size=${ramdisksize},uid=tomcat7,mode=755",
    require => [
      File['/srv/sts'],
      User['tomcat7'],
    ],
  }

  class { 'archiver_appliance':
    nodes_fqdn                    => $archiver_nodes,
    loadbalancer                  => $loadbalancer,
    archappl_tarball_url          => $archappl_tarball_url,
    archappl_tarball_md5sum       => $archappl_tarball_md5sum,
    tomcatjdbc_tarball_url        => $tomcatjdbc_tarball_url,
    tomcatjdbc_tarball_md5sum     => $tomcatjdbc_tarball_md5sum,
    short_term_storage            => '/srv/sts',
    mid_term_storage              => '/srv/mts',
    long_term_storage             => '/srv/lts',
    require                       => Mount['/srv/sts'],
  }

  apt::source { 'nsls2repo':
    location    => 'http://epics.nsls2.bnl.gov/debian/',
    release     => 'wheezy',
    repos       => 'main contrib',
    include_src => false,
    key         => '256355f9',
    key_source  => 'http://epics.nsls2.bnl.gov/debian/repo-key.pub',
  }

  # Packages in controls repo are not signed, yet! Thus we use NSLS-II repo for now.
  #apt::source { 'controlsrepo':
  #  location    => 'http://apt.hcl.nscl.msu.edu/controls/',
  #  release     => 'wheezy',
  #  repos       => 'main',
  #  include_src => false,
  #  key         => '256355f9',
  #  key_source  => 'http://epics.nsls2.bnl.gov/debian/repo-key.pub',
  #}

  package { 'epics-catools':
    ensure  => installed,
    require => Apt::Source['nsls2repo'],
  }
}

node 'testioc.example.com' {
  apt::source { 'nsls2repo':
    location    => 'http://epics.nsls2.bnl.gov/debian/',
    release     => 'wheezy',
    repos       => 'main contrib',
    include_src => false,
    key         => 'BE16DA67',
    key_source  => 'http://epics.nsls2.bnl.gov/debian/repo-key.pub',
  }

  class { 'epics_softioc':
    iocbase => $iocbase,
  }

  package { 'git':
    ensure => installed,
  }

  vcsrepo { $vcsbase:
    ensure   => present,
    provider => git,
    source   => 'https://github.com/diirt/flint.git',
    require  => Package['git'],
  }

  file { "${iocbase}/control":
    ensure  => link,
    target  => "${vcsbase}/flint-controller/control",
    require => Vcsrepo[$vcsbase],
  }

  epics_softioc::ioc { 'control':
    ensure      => running,
    bootdir     => '',
    consolePort => '4051',
    enable      => true,
    require     => File["${vcsbase}/flint-ca/control"],
    subscribe   => Vcsrepo[$vcsbase],
  }

  file { '/etc/init.d/testcontroller':
    source  => '/vagrant/files/init.d/testcontroller',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Vcsrepo[$vcsbase],
  }

  service { 'testcontroller':
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => File['/etc/init.d/testcontroller'],
  }

  epics_softioc::ioc { 'phase1':
    bootdir     => '',
    consolePort => '4053',
    enable      => false,
    require     => Vcsrepo[$vcsbase],
    subscribe   => Vcsrepo[$vcsbase],
  }

  epics_softioc::ioc { 'typeChange1':
    bootdir     => '',
    consolePort => '4053',
    enable      => false,
    require     => Vcsrepo[$vcsbase],
    subscribe   => Vcsrepo[$vcsbase],
  }

  epics_softioc::ioc { 'typeChange2':
    bootdir     => '',
    consolePort => '4053',
    enable      => false,
    require     => Vcsrepo[$vcsbase],
    subscribe   => Vcsrepo[$vcsbase],
  }

  Apt::Source['nsls2repo'] -> Class['epics_softioc']
}

node 'archiveviewer.example.com' {
  include apt

  apt::source { 'nsls2repo':
    location    => 'http://epics.nsls2.bnl.gov/debian/',
    release     => 'wheezy',
    repos       => 'main contrib',
    include_src => false,
    key         => '256355f9',
    key_source  => 'http://epics.nsls2.bnl.gov/debian/repo-key.pub',
  }

  package { 'task-lxde-desktop':
    ensure => installed,
  }

  package { 'openjdk-7-jdk':
    ensure => installed,
  }

  exec { 'use openjdk 7 by default':
    command => '/usr/sbin/update-java-alternatives -s java-1.7.0-openjdk-amd64',
    require => Package['openjdk-7-jdk'],
  }

  package { 'epics-catools':
    ensure  => installed,
    require => Apt::Source['nsls2repo'],
  }

  wget::fetch { 'archiveviewer':
    source      => 'http://downloads.sourceforge.net/project/epicsarchiverap/snapshots/archiveviewer.jar',
    destination => '/usr/local/lib/archiveviewer.jar',
  }

  file { '/usr/local/bin/archiveviewer.sh':
    ensure  => file,
    source  => '/vagrant/files/archiveviewer.sh',
    owner   => root,
    mode    => '0755',
    require => Wget::Fetch['archiveviewer'],
  }

  file { '/usr/share/applications/archiveviewer.desktop':
    ensure  => file,
    source  => '/vagrant/files/archiveviewer',
    require => File['/usr/local/bin/archiveviewer.sh'],
  }

  service { 'lightdm':
    ensure  => running,
    enable  => true,
    require => Package['task-lxde-desktop'],
  }
}

node 'loadbalancer.example.com' {
  class { 'archiver_appliance::loadbalancer':
    nodes_fqdn => $archiver_nodes,
  }
}
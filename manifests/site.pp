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

$iocbase = '/usr/local/lib/iocapps'

$archappl_tarball_url = 'http://downloads.sourceforge.net/project/epicsarchiverap/snapshots/archappl_v0.0.1_SNAPSHOT_19-December-2013T10-26-34.tar.gz'
$archappl_tarball_md5sum = '36d68a803d52bb3cbfb676a79c93799e'
$mysqlconnector_tarball_url = 'http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.28.tar.gz'
$mysqlconnector_tarball_md5sum = 'fe5289a1cf7ca0dee85979c86c602db3'
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

node 'archappl0.example.com' {
  class { 'archiver_appliance::node':
    nodes_fqdn                    => $archiver_nodes,
    loadbalancer                  => $loadbalancer,
    archappl_tarball_url          => $archappl_tarball_url,
    archappl_tarball_md5sum       => $archappl_tarball_md5sum,
    mysqlconnector_tarball_url    => $mysqlconnector_tarball_url,
    mysqlconnector_tarball_md5sum => $mysqlconnector_tarball_md5sum,
    tomcatjdbc_tarball_url        => $tomcatjdbc_tarball_url,
    tomcatjdbc_tarball_md5sum     => $tomcatjdbc_tarball_md5sum,
  }
}

node 'archappl1.example.com' {
  class { 'archiver_appliance::node':
    nodes_fqdn                    => $archiver_nodes,
    loadbalancer                  => $loadbalancer,
    archappl_tarball_url          => $archappl_tarball_url,
    archappl_tarball_md5sum       => $archappl_tarball_md5sum,
    mysqlconnector_tarball_url    => $mysqlconnector_tarball_url,
    mysqlconnector_tarball_md5sum => $mysqlconnector_tarball_md5sum,
    tomcatjdbc_tarball_url        => $tomcatjdbc_tarball_url,
    tomcatjdbc_tarball_md5sum     => $tomcatjdbc_tarball_md5sum,
  }
}

node 'archappl2.example.com' {
  class { 'archiver_appliance::node':
    nodes_fqdn   => $archiver_nodes,
    loadbalancer => $loadbalancer,
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

  class { 'incommon_ca_cert':
  }

  package { 'git':
    ensure => installed,
  }

  vcsrepo { $iocbase:
    ensure   => present,
    provider => git,
    source   => 'https://stash.nscl.msu.edu/scm/test/pv_manager_test_iocs.git',
    require  => [
      Package['git'],
      Class['incommon_ca_cert'],
    ],
  }

  epics_softioc::ioc { 'control':
    ensure      => running,
    bootdir     => '',
    consolePort => '4051',
    enable      => true,
    require     => Vcsrepo[$iocbase],
    subscribe   => Vcsrepo[$iocbase],
  }

  file { '/etc/init.d/testcontroller':
    source => '/vagrant/files/init.d/testcontroller',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  service { 'testcontroller':
    ensure => running,
    enable => true,
  }

  epics_softioc::ioc { 'phase1':
    bootdir     => '',
    consolePort => '4053',
    enable      => false,
    require     => Vcsrepo[$iocbase],
    subscribe   => Vcsrepo[$iocbase],
  }

  epics_softioc::ioc { 'typeChange1':
    bootdir     => '',
    consolePort => '4053',
    enable      => false,
    require     => Vcsrepo[$iocbase],
    subscribe   => Vcsrepo[$iocbase],
  }

  epics_softioc::ioc { 'typeChange2':
    bootdir     => '',
    consolePort => '4053',
    enable      => false,
    require     => Vcsrepo[$iocbase],
    subscribe   => Vcsrepo[$iocbase],
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
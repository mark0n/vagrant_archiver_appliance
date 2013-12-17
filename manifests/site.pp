include apt

# for some reason we need to run apt-get update before we can start. This
# seems to be needed only for provisioning of VMs with Vagrant.
exec { "apt-update":
  command => "/usr/bin/apt-get update"
}
Exec["apt-update"] -> Package <| |>

apt::source { 'nsclmirror':
  location	=> 'http://nsclmirror.nscl.msu.edu/debian/',
  release	=> 'wheezy',
  repos		=> 'main contrib non-free',
  include_src	=> false,
}
Apt::Source['nsclmirror'] -> Package <| |>

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

File { owner => root, group => root, mode => '0644' }

package { 'epics-catools':
  ensure	=> installed,
  require	=> Apt::Source['nsls2repo'],
}

package { 'openjdk-7-jdk':
  ensure	=> installed,
}

package { 'tomcat7':
  ensure	=> installed,
}

class { '::mysql::server':
  package_name		=> 'mysql-server',
  package_ensure	=> present,
  service_enabled	=> true,
}

mysql::db { 'archappl':
  user		=> 'archappl',
  password	=> 'archappl',
  host		=> 'localhost',
# UTF8 unfortunately does not work right now since archive appliance uses to long keys, so we have to use the old-fashioned MySQL default :-(
  charset	=> 'latin1',
  collate	=> 'latin1_swedish_ci',
  grant		=> ['ALL'],
}

exec { 'create MySQL tables for archiver appliance':
  command	=> '/usr/bin/mysql --user=archappl --password=archappl --database=archappl < /tmp/install_scripts/archappl_mysql.sql',
  onlyif	=> "/usr/bin/test `/usr/bin/mysql --user=archappl --password=archappl --database=archappl --batch --skip-column-names -e 'SHOW TABLES' | /usr/bin/wc -l` -lt 4",
  require	=> Mysql::Db['archappl'],
}

package { 'jsvc':
  ensure	=> installed,
}

package { 'libmysql-java':
  ensure	=> installed,
}

file { '/usr/share/tomcat7/lib/log4j.properties':
  ensure	=> file,
  source	=> '/vagrant/files/log4j.properties',
  require	=> Package['tomcat7'],
}

file { '/etc/archappl':
  ensure	=> directory,
  owner		=> root,
  group		=> root,
  mode		=> 755,
}

file { '/etc/archappl/appliances.xml':
  ensure	=> file,
  content	=> template('/vagrant/templates/appliances.xml'),
}

exec { 'extract archiver appliance archive':
  command	=> '/bin/tar -xzf /vagrant/files/archappl_v0.0.1_SNAPSHOT_19-November-2013T10-01-18.tar.gz',
  cwd		=> '/tmp/',
  creates	=> '/tmp/engine.war',
}

exec { 'deploy multiple tomcats':
  command	=> '/usr/bin/python /tmp/install_scripts/deployMultipleTomcats.py /var/lib/tomcat7-archappl/',
  environment	=> [
    'TOMCAT_HOME=/var/lib/tomcat7/',
    'ARCHAPPL_MYIDENTITY=appliance0',
    'ARCHAPPL_APPLIANCES=/etc/archappl/appliances.xml',
  ],
  creates	=> '/var/lib/tomcat7-archappl',
  require	=> [
    Package['tomcat7'],
    Exec['extract archiver appliance archive'],
    File['/etc/archappl/appliances.xml'],
  ],
  notify	=> File['/var/lib/tomcat7-archappl'],
}

file { '/var/lib/tomcat7-archappl':
  ensure	=> directory,
  recurse	=> true,
  owner		=> tomcat7,
  group		=> tomcat7,
}

file { '/usr/share/tomcat7/lib/mysql-connector-java-5.1.27-bin.jar':
  ensure	=> file,
  source	=> '/vagrant/files/mysql-connector-java-5.1.27-bin.jar',
  require	=> Package['tomcat7'],
}

exec { 'install Tomcat JDBC Connection Pool':
  command	=> '/usr/bin/unzip /vagrant/files/apache-tomcat-jdbc-1.1.0.1-bin.zip -d /usr/share/tomcat7/lib/',
  creates	=> '/usr/share/tomcat7/lib/tomcat-jdbc.jar',
  require	=> Package['tomcat7'],
}

file { '/var/lib/tomcat7-archappl/engine/webapps/engine.war':
  ensure	=> file,
  source	=> '/tmp/engine.war',
  owner		=> tomcat7,
  require	=> Exec['deploy multiple tomcats'],
}

file { '/var/lib/tomcat7-archappl/etl/webapps/etl.war':
  ensure	=> file,
  source	=> '/tmp/etl.war',
  owner		=> tomcat7,
  require	=> Exec['deploy multiple tomcats'],
}

file { '/var/lib/tomcat7-archappl/mgmt/webapps/mgmt.war':
  ensure	=> file,
  source	=> '/tmp/mgmt.war',
  owner		=> tomcat7,
  require	=> Exec['deploy multiple tomcats'],
}

file { '/var/lib/tomcat7-archappl/retrieval/webapps/retrieval.war':
  ensure	=> file,
  source	=> '/tmp/retrieval.war',
  owner		=> tomcat7,
  require	=> Exec['deploy multiple tomcats'],
}

file { '/var/lib/tomcat7-archappl/engine/conf/context.xml':
  ensure	=> file,
  source	=> '/vagrant/files/context.xml',
  owner		=> tomcat7,
  require	=> Exec['deploy multiple tomcats'],
}

file { '/var/lib/tomcat7-archappl/etl/conf/context.xml':
  ensure	=> file,
  source	=> '/vagrant/files/context.xml',
  owner		=> tomcat7,
  require	=> Exec['deploy multiple tomcats'],
}

file { '/var/lib/tomcat7-archappl/mgmt/conf/context.xml':
  ensure	=> file,
  source	=> '/vagrant/files/context.xml',
  owner		=> tomcat7,
  require	=> Exec['deploy multiple tomcats'],
}

file { '/var/lib/tomcat7-archappl/retrieval/conf/context.xml':
  ensure	=> file,
  source	=> '/vagrant/files/context.xml',
  owner		=> tomcat7,
  require	=> Exec['deploy multiple tomcats'],
}

file { '/srv/sts':
  ensure	=> directory,
}

file { '/srv/mts':
  ensure	=> directory,
}

file { '/srv/lts':
  ensure	=> directory,
}

file { '/etc/default/archappl-engine':
  ensure	=> file,
  source	=> '/vagrant/files/init.d/archappl-engine',
  notify	=> Service['archappl-engine'],
}

file { '/etc/default/archappl-etl':
  ensure	=> file,
  source	=> '/vagrant/files/default/archappl-etl',
  notify	=> Service['archappl-etl'],
}

file { '/etc/default/archappl-mgmt':
  ensure	=> file,
  source	=> '/vagrant/files/default/archappl-mgmt',
  notify	=> Service['archappl-mgmt'],
}

file { '/etc/default/archappl-retrieval':
  ensure	=> file,
  source	=> '/vagrant/files/default/archappl-retrieval',
  notify	=> Service['archappl-retrieval'],
}

file { '/etc/init.d/archappl-engine':
  ensure	=> file,
  source	=> '/vagrant/files/init.d/archappl-engine',
  mode		=> 755,
}

file { '/etc/init.d/archappl-etl':
  ensure	=> file,
  source	=> '/vagrant/files/init.d/archappl-etl',
  mode		=> 755,
}

file { '/etc/init.d/archappl-mgmt':
  ensure	=> file,
  source	=> '/vagrant/files/init.d/archappl-mgmt',
  mode		=> 755,
}

file { '/etc/init.d/archappl-retrieval':
  ensure	=> file,
  source	=> '/vagrant/files/init.d/archappl-retrieval',
  mode		=> 755,
}

service { 'archappl-mgmt':
  ensure	=> stopped,
  enable	=> true,
  hasrestart	=> true,
  hasstatus	=> true,
  require	=> [
    File['/usr/share/tomcat7/lib/mysql-connector-java-5.1.27-bin.jar'],
    Exec['install Tomcat JDBC Connection Pool'],
    Package['openjdk-7-jdk'],
    Package['libmysql-java'],
    File['/usr/share/tomcat7/lib/log4j.properties'],
    Exec['create MySQL tables for archiver appliance'],
    File['/var/lib/tomcat7-archappl/mgmt/webapps/mgmt.war'],
    File['/var/lib/tomcat7-archappl/mgmt/conf/context.xml'],
    File['/srv/sts'],
    File['/srv/mts'],
    File['/srv/lts'],
    File['/etc/default/archappl-mgmt'],
    File['/etc/init.d/archappl-mgmt'],
  ],
}

service { 'archappl-etl':
  ensure	=> running,
  enable	=> true,
  hasrestart	=> true,
  hasstatus	=> true,
  require	=> [
    File['/usr/share/tomcat7/lib/mysql-connector-java-5.1.27-bin.jar'],
    Exec['install Tomcat JDBC Connection Pool'],
    Package['openjdk-7-jdk'],
    Package['libmysql-java'],
    File['/usr/share/tomcat7/lib/log4j.properties'],
    Exec['create MySQL tables for archiver appliance'],
    File['/var/lib/tomcat7-archappl/etl/webapps/etl.war'],
    File['/var/lib/tomcat7-archappl/etl/conf/context.xml'],
    File['/srv/sts'],
    File['/srv/mts'],
    File['/srv/lts'],
    File['/etc/default/archappl-etl'],
    File['/etc/init.d/archappl-etl'],
  ],
}

service { 'archappl-retrieval':
  ensure	=> running,
  enable	=> true,
  hasrestart	=> true,
  hasstatus	=> true,
  require	=> [
    File['/usr/share/tomcat7/lib/mysql-connector-java-5.1.27-bin.jar'],
    Exec['install Tomcat JDBC Connection Pool'],
    Package['openjdk-7-jdk'],
    Package['libmysql-java'],
    File['/usr/share/tomcat7/lib/log4j.properties'],
    Exec['create MySQL tables for archiver appliance'],
    File['/var/lib/tomcat7-archappl/retrieval/webapps/retrieval.war'],
    File['/var/lib/tomcat7-archappl/retrieval/conf/context.xml'],
    File['/srv/sts'],
    File['/srv/mts'],
    File['/srv/lts'],
    File['/etc/default/archappl-retrieval'],
    File['/etc/init.d/archappl-retrieval'],
  ],
}

service { 'archappl-engine':
  ensure	=> stopped,
  enable	=> true,
  hasrestart	=> true,
  hasstatus	=> true,
  require	=> [
    File['/usr/share/tomcat7/lib/mysql-connector-java-5.1.27-bin.jar'],
    Exec['install Tomcat JDBC Connection Pool'],
    Package['openjdk-7-jdk'],
    Package['libmysql-java'],
    File['/usr/share/tomcat7/lib/log4j.properties'],
    Exec['create MySQL tables for archiver appliance'],
    File['/var/lib/tomcat7-archappl/engine/webapps/engine.war'],
    File['/var/lib/tomcat7-archappl/engine/conf/context.xml'],
    File['/srv/sts'],
    File['/srv/mts'],
    File['/srv/lts'],
    File['/etc/default/archappl-engine'],
    File['/etc/init.d/archappl-engine'],
  ],
}
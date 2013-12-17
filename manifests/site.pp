import 'classes/*.pp'

node 'archappl0.example.com' {
  include apt
  include vagrant
  #include use_local_deb_mirror
  #include use_nscl_deb_mirror
  include archiver_appliance

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
    ensure	=> installed,
    require	=> Apt::Source['nsls2repo'],
  }
}
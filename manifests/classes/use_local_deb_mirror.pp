class use_local_deb_mirror {
  file { '/mnt/mirror':
    ensure	=> directory,
  }

  mount { 'local Debian mirror':
    name	=> '/mnt/mirror',
    ensure	=> mounted,
    atboot	=> true,
    device	=> '192.168.1.250:/srv/hdd/debmirror/mirror',
    fstype	=> 'nfs',
    options	=> 'ro',
    require	=> File['/mnt/mirror'],
  }

  apt::source { 'local Debian mirror':
    location	=> 'file:/mnt/mirror',
    release	=> 'wheezy',
    repos	=> 'main contrib non-free',
    include_src	=> false,
    require	=> Mount['local Debian mirror'],
  }

  Apt::Source['local Debian mirror'] -> Package <| |>
}
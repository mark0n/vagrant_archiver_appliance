class use_nscl_deb_mirror {
  apt::source { 'nsclmirror':
    location	=> 'http://nsclmirror.nscl.msu.edu/debian/',
    release	=> 'wheezy',
    repos	=> 'main contrib non-free',
    include_src	=> false,
  }
  Apt::Source['nsclmirror'] -> Package <| |>
}
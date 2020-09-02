#
# @summary allow to bootstrap pip when python is managed from other module
#
# @param version should be pip or pip3
# @param manage_python if python module will manage deps
# @param http_proxy Proxy server to use for outbound connections.
#
# @example
#   class { 'python_deprecated::pip::bootstrap':
#     version => 'pip',
#   }
class python_deprecated::pip::bootstrap (
  Enum['pip', 'pip3'] $version            = 'pip',
  Variant[Boolean, String] $manage_python = false,
  Optional[Stdlib::HTTPUrl] $http_proxy   = undef,
) inherits python_deprecated::params {
  if $manage_python {
    include python_deprecated
  } else {
    $target_src_pip_path = $facts['os']['family'] ? {
      'AIX' => '/opt/freeware/bin',
      default => '/usr/bin'
    }

    $environ = $http_proxy ? {
      undef   => [],
      default => $facts['os']['family'] ? {
        'AIX'   => [ "http_proxy=${http_proxy}", "https_proxy=${http_proxy}" ],
        default => [ "HTTP_PROXY=${http_proxy}", "HTTPS_PROXY=${http_proxy}" ],
      }
    }

    if $version == 'pip3' {
      exec { 'bootstrap pip3':
        command     => '/usr/bin/curl https://bootstrap.pypa.io/get-pip.py | python3',
        environment => $environ,
        unless      => 'which pip3',
        path        => $python_deprecated::params::pip_lookup_path,
        require     => Package['python3'],
      }
      # puppet is opinionated about the pip command name
      file { 'pip3-python':
        ensure  => link,
        path    => '/usr/bin/pip3',
        target  => "${target_src_pip_path}/pip${facts['python_deprecated_python3_release']}",
        require => Exec['bootstrap pip3'],
      }
    } else {
      exec { 'bootstrap pip':
        command     => '/usr/bin/curl https://bootstrap.pypa.io/get-pip.py | python',
        environment => $environ,
        unless      => 'which pip',
        path        => $python_deprecated::params::pip_lookup_path,
        require     => Package['python'],
      }
      # puppet is opinionated about the pip command name
      file { 'pip-python':
        ensure  => link,
        path    => '/usr/bin/pip',
        target  => "${target_src_pip_path}/pip${facts['python_deprecated_python2_release']}",
        require => Exec['bootstrap pip'],
      }
    }
  }
}

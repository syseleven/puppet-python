# @api private
# @summary Installs core python packages
#
# @example
#  include python_deprecated::install
#
class python_deprecated::install {

  $python = $python_deprecated::version ? {
    'system'              => 'python',
    'pypy'                => 'pypy',
    /\A(python)?([0-9]+)/ => "python${2}",
    /\Arh-python[0-9]{2}/ => $python_deprecated::version,
    default               => "python${python_deprecated::version}",
  }

  $pythondev = $facts['os']['family'] ? {
    'AIX'    => "${python}-devel",
    'RedHat' => "${python}-devel",
    'Debian' => "${python}-dev",
    'Suse'   => "${python}-devel",
    'Gentoo' => undef,
  }

  $pip_ensure = $python_deprecated::pip ? {
    true    => 'present',
    false   => 'absent',
    default => $python_deprecated::pip,
  }

  $venv_ensure = $python_deprecated::virtualenv ? {
    true    => 'present',
    false   => 'absent',
    default => $python_deprecated::virtualenv,
  }

  if $venv_ensure == 'present' {
    $dev_ensure = 'present'
    unless $python_deprecated::dev {
      # Error: python2-devel is needed by (installed) python-virtualenv-15.1.0-2.el7.noarch
      # Python dev is required for virtual environment, but python environment is not required for python dev.
      notify { 'Python virtual environment is dependent on python dev': }
    }
  } else {
    $dev_ensure = $python_deprecated::dev ? {
      true    => 'present',
      false   => 'absent',
      default => $python_deprecated::dev,
    }
  }

  package { 'python':
    ensure => $python_deprecated::ensure,
    name   => $python,
  }

  package { 'virtualenv':
    ensure  => $venv_ensure,
    name    => "${python}-virtualenv",
    require => Package['python'],
  }

  case $python_deprecated::provider {
    'pip': {

      package { 'pip':
        ensure  => $pip_ensure,
        require => Package['python'],
      }

      if $pythondev {
        package { 'python-dev':
          ensure => $dev_ensure,
          name   => $pythondev,
        }
      }

      # Respect the $pip_ensure setting
      unless $pip_ensure == 'absent' {
        # Install pip without pip, see https://pip.pypa.io/en/stable/installing/.
        include 'python_deprecated::pip::bootstrap'

        Exec['bootstrap pip'] -> File['pip-python'] -> Package <| provider == pip |>

        Package <| title == 'pip' |> {
          name     => 'pip',
          provider => 'pip',
        }
        if $pythondev {
          Package <| title == 'virtualenv' |> {
            name     => 'virtualenv',
            provider => 'pip',
            require  => Package['python-dev'],
          }
        } else {
          Package <| title == 'virtualenv' |> {
            name     => 'virtualenv',
            provider => 'pip',
          }
        }
      }
    }
    'scl': {
      # SCL is only valid in the RedHat family. If RHEL, package must be
      # enabled using the subscription manager outside of puppet. If CentOS,
      # the centos-release-SCL will install the repository.
      if $python_deprecated::manage_scl {
        $install_scl_repo_package = $facts['os']['name'] ? {
          'CentOS' => 'present',
          default  => 'absent',
        }

        package { 'centos-release-scl':
          ensure => $install_scl_repo_package,
          before => Package['scl-utils'],
        }
        package { 'scl-utils':
          ensure => 'present',
          before => Package['python'],
        }

        Package['scl-utils'] -> Package["${python}-scldevel"]

        if $pip_ensure != 'absent' {
          Package['scl-utils'] -> Exec['python-scl-pip-install']
        }
      }

      # This gets installed as a dependency anyway
      # package { "${python_deprecated::version}-python-virtualenv":
      #   ensure  => $venv_ensure,
      #   require => Package['scl-utils'],
      # }
      package { "${python}-scldevel":
        ensure => $dev_ensure,
      }
      if $pip_ensure != 'absent' {
        exec { 'python-scl-pip-install':
          command => "${python_deprecated::exec_prefix}easy_install pip",
          path    => ['/usr/bin', '/bin'],
          creates => "/opt/rh/${python_deprecated::version}/root/usr/bin/pip",
        }
      }
    }
    'rhscl': {
      # rhscl is RedHat SCLs from softwarecollections.org
      if $python_deprecated::rhscl_use_public_repository {
        $scl_package = "rhscl-${python_deprecated::version}-epel-${::operatingsystemmajrelease}-${::architecture}"
        package { $scl_package:
          source   => "https://www.softwarecollections.org/en/scls/rhscl/${python_deprecated::version}/epel-${::operatingsystemmajrelease}-${::architecture}/download/${scl_package}.noarch.rpm",
          provider => 'rpm',
          tag      => 'python-scl-repo',
        }
      }

      Package <| title == 'python' |> {
        tag => 'python-scl-package',
      }

      Package <| title == 'virtualenv' |> {
        name => "${python}-python-virtualenv",
      }

      package { "${python}-scldevel":
        ensure => $dev_ensure,
        tag    => 'python-scl-package',
      }

      package { "${python}-python-pip":
        ensure => $pip_ensure,
        tag    => 'python-pip-package',
      }

      if $python_deprecated::rhscl_use_public_repository {
        Package <| tag == 'python-scl-repo' |>
        -> Package <| tag == 'python-scl-package' |>
      }

      Package <| tag == 'python-scl-package' |>
      -> Package <| tag == 'python-pip-package' |>
    }
    'anaconda': {
      $installer_path = '/var/tmp/anaconda_installer.sh'

      file { $installer_path:
        source => $python_deprecated::anaconda_installer_url,
        mode   => '0700',
      }
      -> exec { 'install_anaconda_python':
        command   => "${installer_path} -b -p ${python_deprecated::anaconda_install_path}",
        creates   => $python_deprecated::anaconda_install_path,
        logoutput => true,
      }
      -> exec { 'install_anaconda_virtualenv':
        command => "${python_deprecated::anaconda_install_path}/bin/pip install virtualenv",
        creates => "${python_deprecated::anaconda_install_path}/bin/virtualenv",
      }
    }
    default: {
      case $facts['os']['family'] {
        'AIX': {
          if String($python_deprecated::version) =~ /^python3/ {
            class { 'python_deprecated::pip::bootstrap':
                    version => 'pip3',
            }
          } else {
            package { 'python-pip':
              ensure   => $pip_ensure,
              require  => Package['python'],
              provider => 'yum',
            }
          }
          if $pythondev {
            package { 'python-dev':
              ensure   => $dev_ensure,
              name     => $pythondev,
              alias    => $pythondev,
              provider => 'yum',
            }
          }

        }
        default: {
          package { 'pip':
            ensure  => $pip_ensure,
            require => Package['python'],
          }
          if $pythondev {
            package { 'python-dev':
              ensure => $dev_ensure,
              name   => $pythondev,
              alias  => $pythondev,
            }
          }

        }
      }

      case $facts['os']['family'] {
        'RedHat': {
          if $pip_ensure != 'absent' {
            if $python_deprecated::use_epel == true {
              include 'epel'
              Class['epel'] -> Package['pip']
            }
          }
          if ($venv_ensure != 'absent') and ($::operatingsystemrelease =~ /^6/) {
            if $python_deprecated::use_epel == true {
              include 'epel'
              Class['epel'] -> Package['virtualenv']
            }
          }

          $virtualenv_package = "${python}-virtualenv"
        }
        'Debian': {
          if fact('lsbdistcodename') == 'trusty' {
            $virtualenv_package = 'python-virtualenv'
          } else {
            $virtualenv_package = 'virtualenv'
          }
        }
        'Gentoo': {
          $virtualenv_package = 'virtualenv'
        }
        default: {
          $virtualenv_package = 'python-virtualenv'
        }
      }

      if String($python_deprecated::version) =~ /^python3/ {
        $pip_category = undef
        $pip_package = "${python}-pip"
        $pip_provider = $python.regsubst(/^.*python3\.?/,'pip3.').regsubst(/\.$/,'')
      } elsif ($::osfamily == 'RedHat') and (versioncmp($::operatingsystemmajrelease, '7') >= 0) {
        $pip_category = undef
        $pip_package = 'python2-pip'
        $pip_provider = pip2
      } elsif $::osfamily == 'Gentoo' {
        $pip_category = 'dev-python'
        $pip_package = 'pip'
        $pip_provider = 'pip'
      } else {
        $pip_category = undef
        $pip_package = 'python-pip'
        $pip_provider = 'pip'
      }

      Package <| title == 'pip' |> {
        name     => $pip_package,
        category => $pip_category,
      }

      Python_deprecated::Pip <| |> {
        pip_provider => $pip_provider,
      }

      Package <| title == 'virtualenv' |> {
        name => $virtualenv_package,
      }
    }
  }

  if $python_deprecated::manage_gunicorn {
    $gunicorn_ensure = $python_deprecated::gunicorn ? {
      true    => 'present',
      false   => 'absent',
      default => $python_deprecated::gunicorn,
    }

    package { 'gunicorn':
      ensure => $gunicorn_ensure,
      name   => $python_deprecated::gunicorn_package_name,
    }
  }
}

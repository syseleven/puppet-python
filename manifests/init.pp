# @summary Installs and manages python, python-dev, python-virtualenv and gunicorn.
#
# @param ensure Desired installation state for the Python package.
# @param version Python version to install. Beware that valid values for this differ a) by the provider you choose and b) by the osfamily/operatingsystem you are using.
#  Allowed values:
#   - provider == pip: everything pip allows as a version after the 'python=='
#   - else: 'system', 'pypy', 3/3.3/...
#      - Be aware that 'system' usually means python 2.X.
#      - 'pypy' actually lets us use pypy as python.
#      - 3/3.3/... means you are going to install the python3/python3.3/...
#        package, if available on your osfamily.
# @param pip Desired installation state for the python-pip package.
# @param dev Desired installation state for the python-dev package.
# @param virtualenv Desired installation state for the virtualenv package
# @param gunicorn Desired installation state for Gunicorn.
# @param manage_gunicorn Allow Installation / Removal of Gunicorn.
# @param provider What provider to use for installation of the packages, except gunicorn and Python itself.
# @param use_epel to determine if the epel class is used.
# @param manage_scl Whether to manage core SCL packages or not.
# @param umask The default umask for invoked exec calls.
#
# @example install python from system python
#   class { 'python_deprecated':
#     version    => 'system',
#     pip        => 'present',
#     dev        => 'present',
#     virtualenv => 'present',
#     gunicorn   => 'present',
#   }
# @example install python3 from scl repo
#   class { 'python_deprecated' :
#     ensure      => 'present',
#     version     => 'rh-python36-python',
#     dev         => 'present',
#     virtualenv  => 'present',
#   }
#
class python_deprecated (
  Enum['absent', 'present', 'latest'] $ensure     = $python_deprecated::params::ensure,
  $version                                        = $python_deprecated::params::version,
  Enum['absent', 'present', 'latest'] $pip        = $python_deprecated::params::pip,
  Enum['absent', 'present', 'latest'] $dev        = $python_deprecated::params::dev,
  Enum['absent', 'present', 'latest'] $virtualenv = $python_deprecated::params::virtualenv,
  Enum['absent', 'present', 'latest'] $gunicorn   = $python_deprecated::params::gunicorn,
  Boolean $manage_gunicorn                        = $python_deprecated::params::manage_gunicorn,
  $gunicorn_package_name                          = $python_deprecated::params::gunicorn_package_name,
  Optional[Enum['pip', 'scl', 'rhscl', 'anaconda', '']] $provider = $python_deprecated::params::provider,
  $valid_versions                                 = $python_deprecated::params::valid_versions,
  Hash $python_pips                               = { },
  Hash $python_virtualenvs                        = { },
  Hash $python_pyvenvs                            = { },
  Hash $python_requirements                       = { },
  Hash $python_dotfiles                           = { },
  Boolean $use_epel                               = $python_deprecated::params::use_epel,
  $rhscl_use_public_repository                    = $python_deprecated::params::rhscl_use_public_repository,
  Stdlib::Httpurl $anaconda_installer_url         = $python_deprecated::params::anaconda_installer_url,
  Stdlib::Absolutepath $anaconda_install_path     = $python_deprecated::params::anaconda_install_path,
  Boolean $manage_scl                             = $python_deprecated::params::manage_scl,
  Optional[Pattern[/[0-7]{1,4}/]] $umask          = undef,
) inherits python_deprecated::params {

  $exec_prefix = $provider ? {
    'scl'   => "/usr/bin/scl enable ${version} -- ",
    'rhscl' => "/usr/bin/scl enable ${version} -- ",
    default => '',
  }

  unless $version =~ Pattern[/\A(python)?[0-9](\.?[0-9])+/,
        /\Apypy\Z/, /\Asystem\Z/, /\Arh-python[0-9]{2}(?:-python)?\Z/] {
    fail("version needs to be pypy, system or a version string like '36', '3.6' or 'python3.6' )")
  }

  # Module compatibility check
  $compatible = [ 'Debian', 'RedHat', 'Suse', 'Gentoo', 'AIX' ]
  if ! ($facts['os']['family'] in $compatible) {
    fail("Module is not compatible with ${::operatingsystem}")
  }

  # Anchor pattern to contain dependencies
  anchor { 'python_deprecated::begin': }
  -> class { 'python_deprecated::install': }
  -> class { 'python_deprecated::config': }
  -> anchor { 'python_deprecated::end': }

  # Set default umask.
  if $umask != undef {
    Exec { umask => $umask }
  }

  # Allow hiera configuration of python resources
  create_resources('python_deprecated::pip', $python_pips)
  create_resources('python_deprecated::pyvenv', $python_pyvenvs)
  create_resources('python_deprecated::virtualenv', $python_virtualenvs)
  create_resources('python_deprecated::requirements', $python_requirements)
  create_resources('python_deprecated::dotfile', $python_dotfiles)

}

# @api private
# @summary Optionally installs the gunicorn service
#
# @example
#  include python_deprecated::config
#
class python_deprecated::config {

  Class['python_deprecated::install'] -> Python_deprecated::Pip <| |>
  Class['python_deprecated::install'] -> Python_deprecated::Requirements <| |>
  Class['python_deprecated::install'] -> Python_deprecated::Virtualenv <| |>

  Python_deprecated::Virtualenv <| |> -> Python_deprecated::Pip <| |>

  if $python_deprecated::manage_gunicorn {
    if $python_deprecated::gunicorn != 'absent' {
      Class['python_deprecated::install'] -> Python_deprecated::Gunicorn <| |>

      Python_deprecated::Gunicorn <| |> ~> Service['gunicorn']

      service { 'gunicorn':
        ensure     => running,
        enable     => true,
        hasrestart => true,
        hasstatus  => false,
        pattern    => '/usr/bin/gunicorn',
      }
    }
  }

}

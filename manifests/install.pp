# Class: rabbitmq::install
#
#   This class manages the rabbitmq package itself.
#
#   Jeff McCune <jeff@puppetlabs.com>
#   Tom McLaughlin <tmclaughlin@hubspot.com>
#
# Parameters:
#  [*package_name*]- name of rabbitmq package
#  [*pkg_ensure*] - ensure value of the rabbitmq package resource
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class rabbitmq::install (
  $package_name,
  $pkg_ensure
) {

  package { $package_name:
    ensure => $pkg_ensure,
  }

}
# Class: rabbitmq::server
#
# This module manages the installation and config of the rabbitmq server
#   it has only been tested on certain version of debian-ish systems
# Parameters:
#  [*port*] - port where rabbitmq server is hosted
#  [*delete_guest_user*] - rather or not to delete the default user
#  [*version*] - version of rabbitmq-server to install
#  [*package_name*] - name of rabbitmq package
#  [*service_name*] - name of rabbitmq service
#  [*service_ensure*] - desired ensure state for service
#  [*stomp_port*] - port stomp should be listening on
#  [*node_ip_address*] - ip address for rabbitmq to bind to
#  [*config*] - contents of config file
#  [*env_config*] - contents of env-config file
#  [*config_cluster*] - whether to configure a RabbitMQ cluster
#  [*cluster_disk_nodes*] - which nodes to cluster with (including the current one)
#  [*erlang_cookie*] - erlang cookie, must be the same for all nodes in a cluster
#  [*wipe_db_on_cookie_change*] - whether to wipe the RabbitMQ data if the specified
#    erlang_cookie differs from the current one. This is a sad parameter: actually,
#    if the cookie indeed differs, then wiping the database is the *only* thing you
#    can do. You're only required to set this parameter to true as a sign that you
#    realise this.
# Requires:
#  stdlib
# Sample Usage:
#
#
#
#
# [Remember: No empty lines between comments and class definition]
class rabbitmq::server(
  $port = '5672',
  $admin_port = '55672',
  $delete_guest_user = false,
  $guest_admin = true, # This is the default. Consider changing this or below.
  $guest_password = 'guest',
  $package_name = 'rabbitmq-server',
  $version = 'UNSET',
  $service_name = 'rabbitmq-server',
  $service_ensure = 'running',
  $config_stomp = false,
  $stomp_port = '6163',
  $config_cluster = false,
  $cluster_disk_nodes = [],
  $node_ip_address = 'UNSET',
  $config='UNSET',
  $env_config='UNSET',
  $erlang_cookie='EOKOWXQREETZSHFNTPEY',
  $wipe_db_on_cookie_change=false,
  $rabbitmq_dl_user = 'UNSET',
  $rabbitmq_dl_pass = 'UNSET',
  $rabbitmq_admin_user = 'UNSET',
  $rabbitmq_admin_pass = 'UNSET'
) {

  validate_bool($delete_guest_user, $config_stomp, $guest_admin)
  validate_re($port, '\d+')
  validate_re($stomp_port, '\d+')

  if $guest_admin == false and $rabbitmq_admin_user == 'UNSET' {
    fail('rabbitmq::server: if $guest_admin is false then $rabbitmq_admin_user must be set')
  }

  if $version == 'UNSET' {
    $version_real = '2.4.1'
    $pkg_ensure_real   = 'present'
  } else {
    $version_real = $version
    $pkg_ensure_real   = $version
  }
  if $config == 'UNSET' {
    $config_real = template("${module_name}/rabbitmq.config")
  } else {
    $config_real = $config
  }
  if $env_config == 'UNSET' {
    $env_config_real = template("${module_name}/rabbitmq-env.conf.erb")
  } else {
    $env_config_real = $env_config
  }
  if $rabbitmq_admin_user == 'UNSET' {
    $real_rabbitmq_admin_user = 'guest'
    $real_rabbitmq_admin_pass = $guest_password
  } else {
    $real_rabbitmq_admin_user = $rabbitmq_admin_user
    $real_rabbitmq_admin_pass = $rabbitmq_admin_pass
  }

  $plugin_dir = "/usr/lib/rabbitmq/lib/rabbitmq_server-${version_real}/plugins"

  package { $package_name:
    ensure => $pkg_ensure_real,
    notify => Class['rabbitmq::service'],
  }

  file { '/etc/rabbitmq':
    ensure  => directory,
    owner   => '0',
    group   => '0',
    mode    => '0644',
    require => Package[$package_name],
  }

  file { 'rabbitmq.config':
    ensure  => file,
    path    => '/etc/rabbitmq/rabbitmq.config',
    content => $config_real,
    owner   => '0',
    group   => '0',
    mode    => '0644',
    require => Package[$package_name],
    notify  => Class['rabbitmq::service'],
  }

  # NOTE: At some point this should either become a concatenated file or we
  # should create our own provider specific file for our user.
  file { 'rabbitmqadmin.conf':
    ensure  => present,
    path    => '/etc/rabbitmq/rabbitmqadmin.conf',
    owner   => '0',
    group   => '0',
    mode    => '0600',
    content => template("${module_name}/rabbitmqadmin.conf.erb")
  }

  if $config_cluster {
    file { 'erlang_cookie':
      path    => '/var/lib/rabbitmq/.erlang.cookie',
      owner   => rabbitmq,
      group   => rabbitmq,
      mode    => '0400',
      content => $erlang_cookie,
      replace => true,
      before  => File['rabbitmq.config'],
      require => Exec['wipe_db'],
    }
    # require authorize_cookie_change

    if $wipe_db_on_cookie_change {
      exec { 'wipe_db':
        command => '/etc/init.d/rabbitmq-server stop; /bin/rm -rf /var/lib/rabbitmq/mnesia',
        require => Package[$package_name],
        unless  => "/bin/grep -qx ${erlang_cookie} /var/lib/rabbitmq/.erlang.cookie"
      }
    } else {
      exec { 'wipe_db':
        command => '/bin/false "Cookie must be changed but wipe_db is false"', # If the cookie doesn't match, just fail.
        require => Package[$package_name],
        unless  => "/bin/grep -qx ${erlang_cookie} /var/lib/rabbitmq/.erlang.cookie"
      }
    }
  }

  file { 'rabbitmq-env.config':
    ensure  => file,
    path    => '/etc/rabbitmq/rabbitmq-env.conf',
    content => $env_config_real,
    owner   => '0',
    group   => '0',
    mode    => '0644',
    notify  => Class['rabbitmq::service'],
  }

  rabbitmq_plugin { 'rabbitmq_management':
    ensure => present,
    notify => Class['rabbitmq::service']
  }

  class { 'rabbitmq::service':
    service_name => $service_name,
    ensure       => $service_ensure,
  }

  # WARN: this is a departure from how upstream handles this user.  If you
  # don't manage the user you're left with a guest user that has admin
  # access.  Here we can choose to delete the user or actually manage it.
  # I'm keeping the guest so that it can download rabbitmqadmin.  We may
  # look at the ability to create arbitrary users here to do the
  # downloading at a later point.  This may not be an issue in later
  # RabbitMQ versions though.
  if $delete_guest_user {
    $guest_ensure = absent
  } else {
    $guest_ensure = present
  }

  rabbitmq_user{ 'guest':
    ensure   => $guest_ensure,
    password => $guest_password,
    admin    => $guest_admin,
    provider => 'rabbitmqctl',
  }

  # Disabling guets's administrator tag removes their ability to access the
  # mgmt console but still leaves them access to read, write, and configure
  # everything.  We should take that away too.
  #
  # FIXME: THIS DOES NOT WORK!  Requires altering the provider to call
  # clear_permissions.
  #
  if $guest_admin == false {
    rabbitmq_user_permissions { 'guest@/':
      provider => 'rabbitmqctl',
    }
  }

  # Create the user for use by rabbitmqadmin and give them proper
  # permissions to alter exchanges.
  #
  # NOTE: The 'administrator' tag is required in order to create access the
  # console.  The rabbitmq_user_permissions are needed to manipulate
  # anything.
  if $rabbitmq_admin_user != 'UNSET' {
    rabbitmq_user{ $rabbitmq_admin_user:
      ensure   => present,
      password => $rabbitmq_admin_pass,
      admin    => true,
      provider => 'rabbitmqctl',
    }

    rabbitmq_user_permissions { "${rabbitmq_admin_user}@/":
      configure_permission => '.*',
      read_permission      => '.*',
      write_permission     => '.*',
      provider             => 'rabbitmqctl',
    }

    $rabbitmq_exchange_user = $rabbitmq_admin_user
  } else {
    $rabbitmq_exchange_user = 'guest'
  }


  if $rabbitmq_dl_user != 'UNSET' {
    $rabbitmqadmin_auth = "${rabbitmq_dl_user}:${rabbitmq_dl_pass}@"
  } else {
    $rabbitmqadmin_auth = ''
  }

  exec { 'Download rabbitmqadmin':
    command => "curl http://${$rabbitmqadmin_auth}localhost:${admin_port}/cli/rabbitmqadmin -o /var/tmp/rabbitmqadmin",
    creates => '/var/tmp/rabbitmqadmin',
    require => [
      Class['rabbitmq::service'],
      Rabbitmq_plugin['rabbitmq_management'],
      Rabbitmq_user[$rabbitmq_dl_user],
    ],
    path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin'
  }

  # XXX: Update the rabbitmq_exchange provider if this changes.
  file { '/usr/local/bin/rabbitmqadmin':
    owner   => 'root',
    group   => 'root',
    source  => '/var/tmp/rabbitmqadmin',
    mode    => '0755',
    require => [Exec['Download rabbitmqadmin'],
                Rabbitmq_user[$rabbitmq_exchange_user]],
  }

  Package[$package_name] ->
  Rabbitmq_plugin<| |> ~>
  Class['rabbitmq::service']

}

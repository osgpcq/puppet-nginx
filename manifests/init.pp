# Class: nginx
#
# Install, enable and configure an NGINX web server.
#
# Parameters:
#  $remove_default_conf:
#    Remove default configuration which gets in the way. Default: true for
#    RHEL/Fedora and variants, false otherwise (non applicable)
#  $env:
#    Array of environment variables NAME=value to set globally. Default: none
#  $user:
#    System user to run as. Default: nginx
#  $worker_processes:
#    Number of system worker processes. Default: processorcount fact value
#  $worker_rlimit_nofile:
#    Change the maximum allowed number of open files on startup. Default: use
#    the system's default.
#  $worker_connections:
#    Maximum number of connections per worker. Default: 1024.
#  $default_type:
#    MIME type for files with none set by the main mime.types file. Default:
#    application/octet-stream.
#  $sendfile: Default: on
#  $tcp_nopush: Default: off
#  $keepalive_timeout: Default: 65
#  $keepalive_requests: Default: 100
#  $send_timeout: Default: 60
#  $log_not_found: Default: off
#  $server_tokens: Default: off
#  $server_name_in_redirect: Default: off
#  $server_names_hash_bucket_size: Default: 64
#  $gzip: Default: on
#  $gzip_min_length: Default: 0
#  $gzip_types: Default: text/plain
#  $geoip_country = Default: false
#  $geoip_city = Default: false
#  $index: Default: index.html
#  $upstream: Default: empty
#  $http_raw_lines: Default: empty
#  $autoindex: Default: off
#  $mime_types:
#    Mime types with extension(s) to append to the main list. Default: empty
#
# Sample Usage :
#  include nginx
#  class { 'nginx':
#    mime_types => {
#      'text/plain' => 'ks repo',
#    }
#  }
#
class nginx (
  $service                       = $::nginx::params::service,
  $confdir                       = $::nginx::params::confdir,
  $package                       = $::nginx::params::package,
  $service_restart               = $::nginx::params::service_restart,
  $remove_default_conf           = $::nginx::params::remove_default_conf,
  $sites_enabled                 = $::nginx::params::sites_enabled,
  $modular                       = $::nginx::params::modular,
  $modules                       = [],
  $modules_absent                = [],
  $selinux                       = true,
  $selboolean_on                 = [],
  $selboolean_off                = [],
  # Main options
  $env                           = [],
  # HTTP module options
  $user                          = $::nginx::params::user,
  $worker_processes              = $facts['processors']['count'],
  $worker_cpu_affinity           = undef,
  $worker_rlimit_nofile          = undef,
  $error_log                     = '/var/log/nginx/error.log',
  $worker_connections            = '1024',
  $default_type                  = 'application/octet-stream',
  $sendfile                      = 'on',
  $tcp_nopush                    = 'off',
  $keepalive_timeout             = '65',
  $keepalive_requests            = '100',
  $send_timeout                  = '60',
  $log_not_found                 = 'off',
  $server_tokens                 = 'off',
  $server_name_in_redirect       = 'off',
  $server_names_hash_bucket_size = '64',
  $gzip                          = 'on',
  $gzip_min_length               = '0',
  $gzip_comp_level               = undef,
  $gzip_proxied                  = undef,
  $gzip_types                    = 'text/plain',
  $geoip_country                 = undef,
  $geoip_city                    = undef,
  $index                         = 'index.html',
  $upstream                      = {},
  $fastcgi_buffers               = undef,
  $fastcgi_buffer_size           = undef,
  $fastcgi_read_timeout          = undef,
  $proxy_buffers                 = undef,
  $proxy_buffer_size             = undef,
  $ssl_ciphers                   = undef,
  $ssl_protocols                 = undef,
  $ssl_prefer_server_ciphers     = undef,
  $ssl_buffer_size               = undef,
  $ssl_session_cache             = undef,
  $ssl_dhparam                   = undef,
  $ssl_ecdh_curve                = undef,
  $ssl_certificate               = undef,
  $ssl_certificate_key           = undef,
  $http_raw_lines                = [],
  # Module options
  $autoindex                     = 'off',
  # mime.types
  $mime_types                    = undef,
) inherits ::nginx::params {

  package { $package:
    ensure => 'installed',
    alias  => 'nginx',
  }

  if $modular == true {
    nginx::module { $modules: }
    nginx::module { $modules_absent: ensure => 'absent' }
  }

  service { $service:
    ensure    => 'running',
    alias     => 'nginx',
    enable    => true,
    restart   => $service_restart,
    hasstatus => true,
    require   => Package['nginx'],
  }

  # Main configuration file
  file { "${confdir}/nginx.conf":
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('nginx/nginx.conf.erb'),
    notify  => Service['nginx'],
    require => Package['nginx'],
  }
  # Directory for configuration snippets
  file { "${confdir}/conf.d":
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Package['nginx'],
  }

  # Default configuration file included in the package (usually unwanted)
  if $remove_default_conf {
    file { "${confdir}/conf.d/default.conf":
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "# Empty, not removed, to not reappear when the package is updated.\n", # lint:ignore:80chars
      require => Package['nginx'],
      notify  => Service['nginx'],
    }
  }

  # Since mime types can only be set from a single "types" directive
  if $mime_types {
    file { "${confdir}/mime.types":
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('nginx/mime.types.erb'),
      require => Package['nginx'],
      notify  => Service['nginx'],
    }
  }

  # SELinux (check with facts that the node has SELinux in Enforcing mode)
  if getvar('facts.os.selinux.enforced') == true {
    Selboolean { persistent => true }
    # Special case : We know when it's required or not
    if $worker_rlimit_nofile {
      selboolean { 'httpd_setrlimit': value => 'on' }
    }
    selboolean { $selboolean_on: value => 'on' }
    selboolean { $selboolean_off: value => 'off' }
  }

}


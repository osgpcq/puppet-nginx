class { 'nginx':
  worker_processes => $facts['processors']['count'],
}

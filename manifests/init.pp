class puppet_metrics_collector (
  String        $output_dir                    = '/opt/puppetlabs/puppet-metrics-collector',
  Integer       $collection_frequency          = 5,
  Integer       $retention_days                = 90,
  String        $puppetserver_metrics_ensure   = present,
  Array[String] $puppetserver_hosts            = puppet_metrics_collector::hosts_with_pe_profile('master'),
  Integer       $puppetserver_port             = 8140,
  String        $puppetdb_metrics_ensure       = 'present',
  Array[String] $puppetdb_hosts                = puppet_metrics_collector::hosts_with_pe_profile('puppetdb'),
  Integer       $puppetdb_port                 = 8081,
  String        $orchestrator_metrics_ensure   = 'present',
  Array[String] $orchestrator_hosts            = puppet_metrics_collector::hosts_with_pe_profile('orchestrator'),
  Integer       $orchestrator_port             = 8143,
  String        $activemq_metrics_ensure       = 'absent',
  Array[String] $activemq_hosts                = puppet_metrics_collector::hosts_with_pe_profile('amq::broker'),
  Integer       $activemq_port                 = 8161,
  Boolean       $symlink_puppet_metrics_collector = true,
  Optional[Enum['influxdb','graphite','splunk_hec']] $metrics_server_type = undef,
  Optional[String]  $metrics_server_hostname  = undef,
  Optional[Integer] $metrics_server_port      = undef,
  Optional[String]  $metrics_server_db_name   = undef,
  Optional[String]  $override_metrics_command = undef,
) {
  $scripts_dir = "${output_dir}/scripts"
  $bin_dir     = "${output_dir}/bin"

  file { [ $output_dir, $scripts_dir, $bin_dir] :
    ensure => directory,
  }

  file { "${scripts_dir}/tk_metrics" :
    ensure => present,
    mode   => '0755',
    source => 'puppet:///modules/puppet_metrics_collector/tk_metrics'
  }

  file { "${scripts_dir}/json2timeseriesdb" :
    ensure => present,
    mode   => '0755',
    source => 'puppet:///modules/puppet_metrics_collector/json2timeseriesdb'
  }

  file { "${bin_dir}/puppet-metrics-collector":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp('puppet_metrics_collector/puppet-metrics-collector.epp', {
      'output_dir' => $output_dir,
    }),
  }

  $symlink_ensure = $symlink_puppet_metrics_collector ? {
    false => 'absent',
    true  => 'symlink',
  }

  file { '/opt/puppetlabs/bin/puppet-metrics-collector':
    ensure => $symlink_ensure,
    target => "${bin_dir}/puppet-metrics-collector",
  }

  include puppet_metrics_collector::puppetserver
  include puppet_metrics_collector::puppetdb
  include puppet_metrics_collector::orchestrator
  include puppet_metrics_collector::activemq

  # LEGACY CLEANUP
  # This exec resource exists to clean up old metrics directories created by
  # the module before it was renamed.
  $legacy_dir      = '/opt/puppetlabs/pe_metric_curl_cron_jobs'
  $safe_output_dir = shellquote($output_dir)

  exec { "migrate ${legacy_dir} directory":
    path    => '/bin:/usr/bin',
    command => "mv ${legacy_dir} ${safe_output_dir}",
    onlyif  => "[ ! -e ${safe_output_dir} -a -e ${legacy_dir} ]",
    before  => File[$output_dir],
  }
}

define java::fetch_ujce_info(
  $ujce_installer,
  $ujce_dir,
) {
}

define java::fetch_ujce(
  $version,
  $ensure             = 'present',

  $user               = 'root',
  $group              = 'root',
  $timeout            = 30000,
  $cache_dir          = '/var/cache/medialibrary',
  $media_library_host = $::media_library_host,
) {


  case $version {
    '8': { $jce_extracted_name = 'UnlimitedJCEPolicyJDK8' }
    '7': { $jce_extracted_name = 'UnlimitedJCEPolicy' }
    '5', '6': { $jce_extracted_name = "ujce${version}" }
    default: { fail("Unsupported version combination: $version") }
  }

  mediafetch { $name:

    ensure             => $ensure,
    extract            => true,
    extracted_name     => $jce_extracted_name,
    digest_type        => 'sha512',

    url_medialibrary   => $media_library_host,
    url_access_level   => 'public',
    url_organization   => 'oracle',
    url_group          => 'java',
    url_product        => "ujce",
    url_os             => 'generic',
    url_arch           => 'noarch',
    url_version        => $version,
    url_extension      => 'zip',

    owner              => $user,
    group              => $group,

    cache_dir          => $cache_dir,
    timeout            => $timeout,
  }

  $ujce_installer = "${cache_dir}/ujce-installer"
  $ujce_dir = "${cache_dir}/${jce_extracted_name}"

  java::fetch_ujce_info { $name:
    ujce_installer => $ujce_installer,
    ujce_dir       => $ujce_dir,
  }

  if (!defined(File[$ujce_installer]) and $ensure != 'absent') {
    file { $ujce_installer:
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      source  => 'puppet:///modules/java/ujce-installer',
      require => Package['perl'],
    }
  }
  if (!defined(Package['perl-Digest-SHA'])) {
    package { 'perl-Digest-SHA': ensure => 'installed' }
  }
}

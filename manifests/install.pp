#
# == Define: java::install
#
# This define installs java from the media library server.
#
# === Parameters
#
# [*media_library_host*]
#   Address of the media library server.
#
# [*version*]
#   Version to install (required)
#
# [*vendor*]
#   Define which Java vendor to use. (Required)
#   Available choice: hotspot, jrockit
#
# [*ensure*]
#   Set to 'present' (default) to install, to 'absent' to remove
#
# [*arch*]
#   Define the architecture to install. Default: 'x86_64'
#
# [*os*]
#   Define the OS to use. Default: 'linux'
#
# [*install_dir*]
#   Define the directory where to install java
#   Default: '/opt/java'
#
# [*cache_dir*]
#   Define the mediafetch download directory
#   Default: '/var/cache/medialibrary'
#
# [*user*]
#   Define the user to be used
#   Default: 'root'
#
# [*group*]
#   Define the group to be used
#   Default: 'root'
#
# [*timeout*]
#   Define the timeout, in seconds, for command executions
#   Default: '300'
#
# [*set_environment*]
#   Define if you want to set Java environment
#   Default: true
#

define java::install_ujce(
  $resname,
  $install_dir,
) {
  $ujce_installer = getparam(Java::Fetch_ujce_info[$resname], 'ujce_installer')
  $ujce_dir       = getparam(Java::Fetch_ujce_info[$resname], 'ujce_dir')

  if (!$ujce_installer or !$ujce_dir) {
    fail("Missing defination of \$ujce_installer or \$ujce_dir in Java::Fetch_ujce_info[$resname]")
  }

  exec { "Unlimited JCE for ${name}":
      command => "${ujce_installer} install ${ujce_dir} ${install_dir}",
      unless  => "${ujce_installer} check ${ujce_dir} ${install_dir}",
      notify  => Common::Ownership[$install_dir],
      require => [
                  File[$ujce_installer],
                 ],

  }
}

define java::install (

  $version,
  $vendor,
  $media_library_host  = $::media_library_host,
  $ensure              = 'present',
  $arch                = '',
  $os                  = 'linux',

  $install_dir         = '/opt/java',
  $cache_dir           = '/var/cache/medialibrary',

  $user                = 'root',
  $group               = 'root',

  $timeout             = 300,

  $current_symlink     = undef,
  $set_environment     = true,

  $custom_java_security = undef,

) {

  if ($current_symlink) {
    if ($current_symlink =~ /^\//) {
      $_current_symlink = $current_symlink
    } else {
      $_current_symlink = sprintf('%s/%s', dirname($install_dir), $_current_symlink)
    }
  } elsif ($set_environment) {
    $_current_symlink = sprintf('%s/current', dirname($install_dir))
  } else {
    $_current_symlink = undef
  }

  case $::operatingsystem {
    'CentOS', 'RedHat', 'OracleLinux', 'Ubuntu', 'Debian', 'Amazon' : { }
    default : { fail("Unsupported operating system: ${::operatingsystem}") }
  }

  $install_extract_dir = "${cache_dir}/extract"
  $install_config_dir  = "${cache_dir}/install"
  $jre_security_config = "${install_dir}/jre/lib/security/java.security"
  $extract             = false

  case $vendor {
    'hotspot': {
      $major_version = regsubst($version, '^(?:1\.)?(\d+)(?:[\.u].*)?$', '\1')
      $jce_version = $major_version
      case $major_version {
        '5': {
          $real_arch = $arch ? {
            ''      => 'amd64',
            default => $arch,
          }
          $installation_name   = "${vendor}-${version}-${os}-${real_arch}"
          $installation_file   = "${installation_name}.bin"
          $url_extension       = 'bin'
          $install_config_file = "${installation_name}-answers.txt"
          $install_config_tmpl = 'java/hotspot_6_answers.txt.erb'
          $install_command     = "${cache_dir}/${installation_file} < ${install_config_dir}/${install_config_file}"
          $current_dir         = "${install_extract_dir}/${installation_file}"
        }
        '6': {
          $real_arch = $arch ? {
            ''      => 'x86_64',
            default => $arch,
          }
          $installation_name   = "${vendor}-${version}-${os}-${real_arch}"
          $installation_file   = "${installation_name}.bin"
          $url_extension       = 'bin'
          $install_config_file = "${installation_name}-answers.txt"
          $install_config_tmpl = 'java/hotspot_6_answers.txt.erb'
          $install_command     = "${cache_dir}/${installation_file} < ${install_config_dir}/${install_config_file}"
          $current_dir         = "${install_extract_dir}/${installation_file}"
        }
        '7', '8': {
          $real_arch = $arch ? {
            ''      => 'x86_64',
            default => $arch,
          }
          $installation_name   = "${vendor}-${version}-${os}-${real_arch}"
          $installation_file   = "${installation_name}.tar.gz"
          $url_extension       = 'tar.gz'
          $install_config_file = "${installation_name}-answers.txt"
          $install_config_tmpl = 'java/hotspot_6_answers.txt.erb'
          $install_command     = "tar -zxf ${cache_dir}/${installation_file}"
          $current_dir         = "${install_extract_dir}/${installation_file}"
        }
        default: {
          fail("Unsupported major version of hotspot: ${major_version} (version: ${version})")
        }
      }
    }
    'jrockit': {
      $major_version = regsubst($version, '^(?:1\.)?(\d+)(?:[\.u].*)?$', '\1')
      $jce_version = $major_version
      $real_arch = $arch ? {
        ''      => 'x86_64',
        default => $arch,
      }
      $installation_name   = "${vendor}-${version}-${os}-${real_arch}"
      $installation_file   = "${installation_name}.bin"
      $url_extension       = 'bin'
      $install_config_file = "${installation_name}-silent.xml"
      $install_config_tmpl = 'java/jrockit_silent.xml.erb'
      $install_command     = "${cache_dir}/${installation_file} -mode=silent -silent_xml=${install_config_dir}/${install_config_file}"
      $current_dir         = $install_dir
    }
    default: {
      fail "Unknown JVM vendor: ${vendor}"
    }
  }

  mediafetch { $installation_name:

    ensure             => $ensure,
    extract            => $extract,

    url_medialibrary   => $media_library_host,
    url_access_level   => 'private',
    url_organization   => 'oracle',
    url_group          => 'java',
    url_product        => $vendor,
    url_os             => $os,
    url_arch           => $real_arch,
    url_version        => $version,
    url_extension      => $url_extension,

    owner              => $user,
    group              => $group,

    cache_dir          => $cache_dir,
    timeout            => $timeout,

  }

  Exec {
    path        => '/usr/bin:/bin:/usr/sbin:/sbin',
    user        => $user,
    group       => $group,
  }

  if (!defined(Package['perl'])) {
    package { "perl": ensure => installed }
  }

  if ($jce_version and $ensure != 'absent') {
    $ujce_installation_name = "Java${major_version} UJCE"
    if (!defined(Java::Fetch_ujce[$ujce_installation_name])) {
      java::fetch_ujce { $ujce_installation_name:
        version            => $jce_version,
        ensure             => $ensure,
        user               => $user,
        group              => $group,
        timeout            => $timeout,
        cache_dir          => $cache_dir,
        media_library_host => $media_library_host,
      }
    }

    java::install_ujce { $installation_name:
      resname     => $ujce_installation_name,
      install_dir => $install_dir,
      require     => [
        Exec["silent install of ${installation_name}"],
        Exec["install cleanup of ${installation_name}"],
        Java::Fetch_ujce[$ujce_installation_name],
      ],
    }
  }

  if !defined(File[$install_config_dir]) {
    file { $install_config_dir:
      ensure  => directory,
      mode    => '0755',
      require => Mediafetch[$installation_name],
    }
  }

  file { "install configuration for ${installation_name}":
    ensure  => $ensure,
    path    => "${install_config_dir}/${install_config_file}",
    content => template($install_config_tmpl),
    mode    => '0444',
    require => File[$install_config_dir],
  }

  # BEGIN IF ENSURE == PRESENT
  if $ensure != 'absent' {

    exec { "chmod ${installation_file}":
      command => "chmod a+x ${cache_dir}/${installation_file}",
      unless  => "test -x ${cache_dir}/${installation_file}",
      require => Mediafetch[$installation_name],
    }

    if !defined(Exec["create installation directory ${install_dir}"]) {
      exec { "create installation directory ${install_dir}":
        command => "mkdir -p ${install_dir}",
        creates => $install_dir,
      }
    }

    if !defined(Exec["create extract directory ${current_dir}"]) {
      exec { "create extract directory ${current_dir}":
        command => "mkdir -p ${current_dir}",
        creates => $current_dir,
      }
    }

    exec { "silent install of ${installation_name}":
      command => $install_command,
      cwd     => $current_dir,
      timeout => $timeout,
      unless  => "test `find ${install_dir} -maxdepth 1 | wc -l` -gt 1",
      require => [
        Exec["chmod ${installation_file}"],
        Exec["create installation directory ${install_dir}"],
        Exec["create extract directory ${current_dir}"],
        File["install configuration for ${installation_name}"],
      ],
    }

    case $vendor {
      'hotspot': {
        exec { "install cleanup of ${installation_name}":
          command => "mv ${current_dir}/`find ${current_dir} -maxdepth 1 -mindepth 1 -printf '%f\n'`/* ${install_dir}",
          require => Exec["silent install of ${installation_name}"],
          unless  => "test `find ${install_dir} -maxdepth 1 | wc -l` -gt 1",
        }
      }
      default : {
        exec { "install cleanup of ${installation_name}":
          command => 'test true',
          unless  => 'test true',
        }
      }
    }

    if(!$custom_java_security) {
      exec { "fix default secure random for ${install_dir}":
        command => "/usr/bin/perl -pi -e 's/dev\\/u?random/dev\\/\\.\\/urandom/' '${jre_security_config}'",
        onlyif  => "/usr/bin/perl -ne 'BEGIN { \$ret = 1; } \$ret = 0 if /dev\\/u?random/ && ! /dev\\/\\.\\/urandom/ ; END { exit \$ret; }' '${jre_security_config}'",
        require => [
          Package['perl'],
          Exec["silent install of ${installation_name}"],
          Exec["install cleanup of ${installation_name}"],
        ],
        before => Common::Ownership[$install_dir],
      }
    }

    common::ownership { $install_dir:
      user    => $user,
      group   => $group,
    }

    if $::selinux != false_string() {
      exec { "fix selinux for ${installation_name}":
        command     => "fixfiles -F restore ${install_dir}",
        refreshonly => true,
        subscribe   => [
          Exec["install cleanup of ${installation_name}"],
          Common::Ownership[$install_dir],
        ],
      }
    }

    $jre_security_config_require = $ensure ? {
      absent  => [],
      default => $install_command ? {
        ''      => Mediafetch[$installation_name],
        default => [
          Exec["silent install of ${installation_name}"],
          Exec["install cleanup of ${installation_name}"],
        ],
      }
    }

    if($custom_java_security) {
      file { $jre_security_config:
        ensure  => $ensure,
        owner   => $user,
        group   => $group,
        require => $jre_security_config_require,
        content => $custom_java_security,
      }
    }

  }
  # END IF ENSURE == PRESENT

  if (!defined(Package['perl'])) {
    package { 'perl': ensure  => installed }
  }

  if ($set_environment) {
    file { '/etc/profile.d/javaenv.sh':
      ensure  => $ensure,
      content => template('java/javaenv.sh.erb'),
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
    }
  }
  if ($_current_symlink) {
    $_symlink_ensure = $ensure ? {
      'absent' => 'absent',
      default  => 'link',
    }
    file { $_current_symlink:
      ensure => $_symlink_ensure,
      target => $install_dir,
      owner => 'root',
      group => 'root',
    }
  }

  if ($ensure == 'absent') {
    exec { "deletion of '${install_dir}'":
      command     => "rm -rf ${install_dir}",
      unless      => "test ! -d ${install_dir}",
      refreshonly => false,
    }
  }

}
#init.pp

class postfix ( 
  $ssl_cert                     = undef,    # SSL Certificate Content
  $ssl_key                      = undef,    # SSL Key Content 
  $postfix_conf                 = undef,    # Hashes with Postfix Configuration Variables
  $smtpd_sender_restrictions    = [],       # Sender Restrictions
  $smtpd_recipient_restrictions = [],       # Recipient Restrictions
  $inet_interfaces              = "all",    # Interfaces which postfix will listen
  $amavis_conf                  = undef,    # Hash with amavis configuration. Undef if not in use.
  $spamassassin_conf            = undef,    # Hash with SpamAssassin config. Undef if not in use.
  $aliases                      = undef,    # Array of hashes with aliases
  $relay_recipients             = [],       # Array of hashes with Relay Recipients
  $mailgroups                   = undef,    # Array of hashes with e-mail groups
  $transport_map                = [],       # Array of hashes with transport map
  $mailuid                      = 'vmail',  # Mail User ID
  $mailgid                      = 'vmail',  # Mail Group ID 
  $use_dovecot_lda              = false,    # Configures Dovecot LDA in master.cf
  $enable_submission            = false,    # Enables SMTP 587 submisssion service
  $submission_options           = {},       # Options for submission
  $smtp_service_options         = {},       # Options for SMTP service
){
  
  package { "postfix": 
    ensure => "present" 
  }
       
  #Postfix main configuration
  file { "/etc/postfix/main.cf":
    owner   => root, 
    group   => root, 
    mode    => 444,
    content => template('postfix/main.cf.erb'),
    require => Package['postfix']
  }
  file { "/etc/postfix/master.cf":
    owner   => root, 
    group   => root, 
    mode    => 444,
    content => template('postfix/master.cf.erb'),
    require => Package['postfix']
  }

  if $aliases { 
    $alias_names = keys($aliases)
  } else {
    $alias_names = []
  }
  
  file { "/etc/aliases":
    owner => root, group => root, mode => 444,
    content => template("postfix/aliases.erb"),
    notify => Exec['newaliases'],
    require => Package['postfix'],
  }
  
  exec { "newaliases":
    cwd => "/etc",
    command => "/usr/bin/newaliases",
    logoutput => true,
    timeout => 30,
    refreshonly => true,
    require => Package['postfix'],
  }
  
  file { "/etc/postfix/transport_map":
    owner => root, group => root, mode => 444,
    content => template("postfix/transport_map.erb"),
    notify => Exec['update transport_map'],
    require => Package['postfix'],
  }
  
  exec { "update transport_map":
    cwd => "/etc/postfix",
    command => "/usr/sbin/postmap transport_map",
    logoutput => true,                
    timeout => 30,
    refreshonly => true,
    require => Package['postfix'],
  }

  #SSL Configuration
  if $ssl_cert and $ssl_key {
    file { "/etc/ssl/certs/ssl-cert-mta.pem":
      owner => root, group => root, mode => 444,
      content => $ssl_cert,
      notify => Service["postfix"],
    }
    file { "/etc/ssl/private/ssl-cert-mta.key":
      owner => root, group => root, mode => 444,
      content => $ssl_key,
      notify => Service["postfix"],
    }
    
  }

  service { postfix:
    enable => true,
    hasrestart => false,
    hasstatus => true,
    ensure => running,
    subscribe => File[ "/etc/postfix/master.cf",
                       "/etc/postfix/main.cf",
                       "/etc/postfix/transport_map",
                       "/etc/aliases" 
                     ],
    require => Package['postfix'],
  }

  
  if $amavis_conf {
    class { 'postfix::amavis':
      amavis_conf => $amavis_conf,
      require => Package['postfix'],
    }
  }

  ##Relay Recipients
  file { "/etc/postfix/relay_recipients":
    ensure => "present",
    content => template("postfix/relay_recipients.erb"),
    notify => Exec["update relay recipients map"],
    require => Package['postfix'],
  }
  exec { "update relay recipients map":
    cwd => "/etc/postfix",
    command => "/usr/sbin/postmap relay_recipients",
    logoutput => true,
    timeout => 30,
    refreshonly => true,
    notify => Service["postfix"],
    require => Package['postfix'],
  }

  ##Groups
  if $mailgroups {
    file { "/etc/postfix/virtual_alias":
      ensure => "present",
      content => template("postfix/virtual_alias.erb"),
      notify => Exec["update virtual alias map"],
      require => Package['postfix'],
    }
    exec { "update virtual alias map":
      cwd => "/etc/postfix",
      command => "/usr/sbin/postmap virtual_alias",
      logoutput => true,
      timeout => 30,
      refreshonly => true,
      notify => Service["postfix"],
      require => Package['postfix'],
    }
  }

}


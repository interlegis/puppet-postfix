#amavis.pp

class postfix::amavis ( $amavis_conf ) {

  #Amavis configuration
  package { "amavisd-new": ensure => "present" }

  # milter filters
  $milter_filters = [ "postfix-policyd-spf-python", "opendkim" ]
  package { $milter_filters: 
    ensure => "present",
    notify => Service["amavis"],
  }         
 
  # file compressing utils
  $amavis_decoders = [  "arj",
                        "cabextract",
                        "cpio",
                        "lhasa",
                        "pax",
                        "rar",
                        "unrar",
                        "zip",
                        "unzip",
                        "ripole",
                        "nomarch" ]
                
  package { $amavis_decoders: 
    ensure => "present",
    notify => Service["amavis"],
  }

  # config do clamav - verificacao antivirus
  package { "clamav-daemon": 
    ensure => "present",
    notify => Service["amavis"],
  }
  service { clamav-daemon:
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus => true,
    require => Package["clamav-daemon"]
  }
  
  # permite ao clamav acessar os diretorios onde o amavis
  # "abre" os emails
  user { "clamav":
    membership => "minimum",
    groups => ["amavis"],
    require => [ Package["clamav-daemon"],
                 Package["amavisd-new"] ]
  }

  service { "amavis":
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus => false,
    pattern => "amavisd",
    subscribe => [
      File["/etc/amavis/conf.d/50-user"],
    ],
    require => [  
      Package[$amavis_decoders],
      Package[$milter_filters],
      Package["clamav-daemon"],
    ],
  }

  file { "/etc/amavis/conf.d/50-user":
    owner => root,
    ensure => "present",
    content => template('postfix/amavis-50-user.erb'),
    require => Package[ ["amavisd-new", $milter_filters] ],
  }
    
  #SpamAssassin Configuration
  package { "spamassassin": ensure => "present" }
  package { "pyzor": ensure => "present" }


  service { spamassassin:
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus => true,
    subscribe => File[ 
        "/etc/default/spamassassin",
        "/etc/spamassassin/local.cf"
    ]
  }
  file { "/etc/default/spamassassin":
    ensure => "present",
    content => template("postfix/default-spamassassin.erb"),
  }
  file { "/etc/spamassassin/local.cf":
    ensure => "present",
    content => template("postfix/spamassassin-local.cf.erb"),
    require => Package["pyzor"],
    notify => Exec["update pyzor servers"],
  }
  exec { "update pyzor servers":
    cwd => "/etc/spamassassin",
    command => "/usr/bin/pyzor --homedir /etc/mail/spamassassin discover",
    logoutput => true,
    timeout => 30,
    refreshonly => true,
    require => Package[ ["pyzor", "spamassassin"] ],
  }
}

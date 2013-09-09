#init.pp

class postfix (	
	$ssl_cert = undef,	    		#SSL Certificate Content
	$ssl_key = undef,	    		#SSL Key Content	
	$postfix_conf = undef,	    		#Hashes with Postfix Configuration Variables
	$smtpd_sender_restrictions = [], 	#Sender Restrictions
	$smtpd_recipient_restrictions = [],	#Recipient Restrictions
	$inet_interfaces = "all",		#Interfaces which postfix will listen
	$amavis_conf = undef,	    		#Hash with amavis configuration. Undef if not in use.
	$spamassassin_conf = undef, 		#Hash with SpamAssassin config. Undef if not in use.
	$aliases = undef,			#Array of hashes with aliases
	$relay_recipients = [],			#Array of hashes with Relay Recipients
	$mailgroups = undef,			#Array of hashes with e-mail groups
	$transport_map = [],			#Array of hashes with transport map
	$dkim_conf = undef,			#OpenDKIM Configuration
	$mailuid = 'vmail',			#Mail User ID
	$mailgid = 'vmail',			#Mail Group ID	
	$use_dovecot_lda = false,		#Configures Dovecot LDA in master.cf
){
	include stdlib
	package { "postfix": ensure => "present" }
       
	#Postfix main configuration
	if $postfix_conf { 
		$itens = keys($postfix_conf)
	} else {
		$itens = []
	}
        file { "/etc/postfix/main.cf":
                owner => root, group => root, mode => 444,
		content => template('postfix/main.cf.erb'),
        }
        file { "/etc/postfix/master.cf":
                owner => root, group => root, mode => 444,
		content => template('postfix/master.cf.erb'),
        }

	if $aliases {	
		$alias_names = keys($aliases)
	} else {
		$alias_names = []
	}
        file { "/etc/aliases":
                owner => root, group => root, mode => 444,
                content => template("postfix/aliases.erb"),
                notify => Exec['newaliases']
        }
        exec { "newaliases":
                cwd => "/etc",
                command => "/usr/bin/newaliases",
                logoutput => true,
                timeout => 30,
                refreshonly => true
        }
        file { "/etc/postfix/transport_map":
                owner => root, group => root, mode => 444,
		content => template("postfix/transport_map.erb"),
                notify => Exec['update transport_map']
        }
        exec { "update transport_map":
                cwd => "/etc/postfix",
                command => "/usr/sbin/postmap transport_map",
                logoutput => true,
                timeout => 30,
                refreshonly => true
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
                subscribe => File[   
                                "/etc/postfix/master.cf",
                                "/etc/postfix/main.cf",
                                "/etc/postfix/transport_map",
                                "/etc/aliases" 
                ],
        }

	
	if $amavis_conf {
		#Amavis configuration
	        package { "amavisd-new": ensure => "present" }

		# milter filters
		$milter_filters = [ "postfix-policyd-spf-python", "opendkim" ]
		package { $milter_filters: 
                        ensure => "present",
                        notify => Service["amavis"],
                }					
 
		# file compressing utils
		$amavis_decoders = [ 	"arj",
					"cabextract",
					"cpio",
					"lha",
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
                	require => Package["clamav-daemon"]
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
			require => [ 	Package[$amavis_decoders],
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

	##Relay Recipients
        file { "/etc/postfix/relay_recipients":
        	ensure => "present",
                content => template("postfix/relay_recipients.erb"),
                notify => Exec["update relay recipients map"],
        }
        exec { "update relay recipients map":
                cwd => "/etc/postfix",
                command => "/usr/sbin/postmap relay_recipients",
                logoutput => true,
                timeout => 30,
                refreshonly => true,
                notify => Service["postfix"]
        }

	##Groups
	if $mailgroups {
        	file { "/etc/postfix/virtual_alias":
                	ensure => "present",
                	content => template("postfix/virtual_alias.erb"),
                	notify => Exec["update virtual alias map"],
        	}
        	exec { "update virtual alias map":
                	cwd => "/etc/postfix",
                	command => "/usr/sbin/postmap virtual_alias",
                	logoutput => true,
                	timeout => 30,
                	refreshonly => true,
                	notify => Service["postfix"]
        	}
	}

  	## DKIM Keys
        define dkimkey {
                file { "/etc/opendkim/keys/$name":
                        ensure => directory,
                        require => File["/etc/opendkim/keys"],
                }
                file { "/etc/opendkim/keys/$name/default.private":
                        ensure => "present",
                        owner => "opendkim", group => "opendkim", mode => 440,
                        source => "puppet:///modules/$module_name/dkimkeys/$name/default.private",
                        require => File["/etc/opendkim/keys/$name"],
                        notify => Service["opendkim"],
                }
                file { "/etc/opendkim/keys/$name/default.txt":
                        ensure => "present",
                        owner => "root", group => "root", mode => 440,
                        source => "puppet:///modules/$module_name/dkimkeys/$name/default.txt",
                        require => File["/etc/opendkim/keys/$name"],
                        notify => Service["opendkim"],
                }
        }


	## DKIM
	if $dkim_conf {
		package { "opendkim": ensure => "present" }
        	service { opendkim:
                	ensure => running,
                	enable => true,
                	hasrestart => true,
                	hasstatus => false,
                	notify => Service["postfix"],
               	 	require => File["/etc/mailname"],
        	}

        	file { "/etc/mailname":
                	content => inline_template('<%= fqdn %>')
        	}

		file { "/etc/opendkim.conf":
	                ensure => "present",
        	        content => template("postfix/opendkim.conf.erb"),
                	notify => Service["opendkim"]
        	}

        	file { "/etc/default/opendkim":
                	ensure => "present",
               	 	content => template("postfix/default-opendkim.erb"),
                	notify => Service["opendkim"]
        	}
        	file { "/etc/opendkim/TrustedHosts":
                	ensure => "present",
			content => template("postfix/opendkim-TrustedHosts.erb"),
                	notify => Service["opendkim"]
        	}
        	file { ["/etc/opendkim","/etc/opendkim/keys"]:
                	ensure => directory,
                	require => Package["opendkim"],
        	}
	
	        file { "/etc/opendkim/KeyTable":
	                content => template('postfix/KeyTable.erb'),
        	        require => File["/etc/opendkim"],
                	notify => Service["opendkim"],
        	}
        	file { "/etc/opendkim/SigningTable":
                	content => template('postfix/SigningTable.erb'),
                	require => File["/etc/opendkim"],
                	notify => Service["opendkim"],
        	}

        	## Install DKIM Keys
		dkimkey { $maildomains: }


	}

}


#DKIM Key Generator for Puppet Masters
class postfix::dkim_key_generator ($maildomains) {
	$keydir = "$settings::confdir/modules/$module_name/files/dkimkeys"
        file { $keydir:
                ensure => directory,
                owner => 'root', group => 'root', mode => '755',
        }
        define dkimkey ($keydir) {
                file { "$keydir/$name":
                        ensure => directory,
                        require => File[$keydir],
                        notify => Exec["opendkim genkey $name"],
                }
                exec { "opendkim genkey $name":
                        cwd => "$keydir/$name",
                        command => "opendkim-genkey -r -d $name",
                        creates => "$keydir/$name/default.private",
                        timeout => 30,
                        refreshonly => true,
                }
                file { ["$keydir/$name/default.private","$keydir/$name/default.txt"]:
                        owner => 'puppet', group => 'root', mode => '440',
                        require => Exec["opendkim genkey $name"],
                }

        }
        dkimkey { $maildomains:
                keydir => $keydir,
	}
}

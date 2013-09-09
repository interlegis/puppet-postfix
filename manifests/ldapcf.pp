#ldapcf.pp

define postfix::ldapcf(	$bind_dn = undef,	
			$bind_pw = undef,
			$server_host = undef,
			$search_base = undef,
			$query_filter = '(&(objectclass=person)(sAMAccountName=%u)',
			$result_attribute = 'sAMAccountName',
			$result_format = '%s',
		) {

	if (!defined(Class['postfix'])) {
    		fail 'Class postfix must be defined before using ldapcf.'
  	}
	if !$bind_dn or !$bind_pw or !$server_host or !$search_base {
		fail 'bind_dn, bind_pw, server_host and search_base variables needed!'
	}

	if (!defined(Package['postfix-ldap'])) {
		package { "postfix-ldap": ensure => "present" }
	}
	
	file { "/etc/postfix/${name}.cf":
                owner => root, group => root, mode => 444,
                content => template('postfix/postfix-ldap.cf.erb'),
                notify => Service["postfix"],
        }

}

module Puppet::Parser::Functions
	newfunction(:get_ldap_mail_addresses, :type => :rvalue) do |args|
        	ldap_users = args[0]
		answer = []
		ldap_users.each do |u|
			addrs = u['proxyaddresses']
			if addrs
				addrs.each do |s|
					if s.split(':')[0].downcase == "smtp"
						answer[answer.length] = s.split(':')[1]
					end
				end
			end	
		end
		return answer	
	end
end

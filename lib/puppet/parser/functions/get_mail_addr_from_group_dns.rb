module Puppet::Parser::Functions
	newfunction(:get_mail_addr_from_group_dns, :type => :rvalue) do |args|
        	mailgroups = args[0]
		answer = []
		mailgroups.each do |g|
			if g['proxyaddresses']
				g['proxyaddresses'].each do |p|
					if g['member'] and p.split(':')[0].downcase == 'smtp'
						i = answer.length
						answer[i] = {}
						answer[i]['mail'] = p.split(':')[1].downcase
						answer[i]['member'] = [] 
						g['member'].each do |m|
							j = answer[i]['member'].length
							answer[i]['member'][j] = function_hiera(["(distinguishedname=#{m})"])[0]['mail']
						end
					end
				end
			end
		end
		return answer.sort{|a,b| a['mail']<=>b['mail']}	
	end
end

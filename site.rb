class UserVariables < Middleman::Extension
	def initialize(app, options_hash={}, &block)
		super
		
		# User variables:
			# Used to limit Google search to this site.
			app.set :search_scope, 'site.example.com'
			
			# Displayed in top-left corner of the page, in the header.
			app.set :site_title, 'Example Site'
			
			# Points to parent organization of this site.
			# must start with http:// or https://
			app.set :parent_url, 'http://master.example.com'
			
			# Text used to render parent_url (set above) and copyright. 
			app.set :parent_title, 'Master Site'
		# End User Variables
	end
end

::Middleman::Extensions.register(:UserVariables, UserVariables)
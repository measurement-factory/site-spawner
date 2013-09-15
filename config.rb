###
# Helpers
###

 #Methods defined in the helpers block are available in templates
 helpers do
	def breadcrumb
		page = current_page
		crumbs = ""
		if page.parent && page.parent.parent then 
			while page.parent do
				if crumbs.empty? then
					crumbs = "<span>#{page.data.title}</span>"
				else
					crumbs = "<a href=\"#{page.url}\">#{page.data.title}</a> &raquo; #{crumbs}"
				end
				page = page.parent
			end
		end
		return crumbs
	end
	def children(page)
		childrenList = ""
		if page.children.length > 0 then
			children = page.children
			children = children.sort_by{ |e| e.data.title.to_s rescue "" }
			show = 5 # Use this to configure how many children are shown.
			
			children.each do |child|
				if child.data.title then
					also = "#{child.data.also}"
					unless also == "true" || also == "false" || also.empty? then
						raise SyntaxError, "also frontmatter variable must be either true/false in YAML format. Current also value: \"#{also}\""
					end
					if also == "false" then
					else
						if show != 0 then
							childrenList << "<a href=\"#{child.url}\">#{child.data.title}</a>"
							childrenList << "  "
							show = show - 1
						else
							break
						end
					end
				end
			end
		end
		return childrenList
	end
	def sitemapGen
		page = current_page.parent
		while page.parent do
			page = page.parent
		end
		list = getHTML(page)
		return list
	end
	def getHTML(page)
		html = ""
		if page.children.length > 0 then
			html << "<ul>\n"
			children = page.children.sort_by{ |e| e.data.title.to_s rescue "" }
			children.each do |page|
				childHtml = getHTML(page)
				next unless page.data.title
				sitemap = "#{page.data.sitemap}"
				sitemap = true if sitemap == "true"  || sitemap.empty?
				sitemap = false if sitemap == "false"
				if page.data.title && sitemap then
					html << "<li>"
						html << "<a href=\"#{page.url}\">#{page.data.title}</a>"
						html << childHtml
					html << "</li>\n"
				end
			end
			html << "</ul>\n"
		end
		return html
	end
	def include(filename)
		if !filename.start_with?('/') then
			dirname = File.dirname(current_page.path)
			filename = "#{:source}/#{dirname}/#{filename}"
		end
		file = File.new(filename, "r")
		# Initialize content string.
		content = ""
		# Get file contents.
		while (line = file.gets)
			content << line
		end
		file.close
		return content
	end
 end

###
# User Variables
##
require 'site.rb'
activate :UserVariables

###
# Middleman
###

# Automatic image dimensions on image_tag helper 
# decreases page load time
activate :automatic_image_sizes

# Makes pretty URLs -> /foobar/ instead of /foobar.html
activate :directory_indexes

# Minify Javascript and HTML - put here primarily for testing
# no :minify css - handled by Sass (:compressed option);
#activate :minify_html

# Activate LiveReload - more info in gemfile
#activate :livereload

set :sass, :style => :expanded, :line_comments => false

set :markdown, :toc_levels => "2,3", :parse_block_html => true, :entity_output => "as_input"

# Build-specific configuration
configure :build do
	# Use relative URLs
	#activate :relative_assets
	# minify CSS
	set :sass, :style => :compressed
	# Minify HTML
	activate :minify_html
	
	# GZIP
	# activate :gzip
	
	# Sets directory from which links will be based.
	# Requires link_to or similar helper.
	# Kramdown's links won't work. Switch to RedCarpet for support.
	# Reference: http://middlemanapp.com/templates/
	 set :http_prefix, "/build/"

	# Or use a different image path
	#set :http_path, "images/"
end

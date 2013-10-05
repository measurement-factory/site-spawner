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
# activate :livereload

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

###
# User Variables
###
# Used to limit Google search to this site.
set :search_scope, 'site.example.com'

# Displayed in top-left corner of the page, in the header.
set :site_title, 'Example Site'

# Points to parent organization of this site.
# must start with http:// or https://
set :parent_url, 'http://master.example.com'

# Text used to render parent_url (set above) and copyright. 
set :parent_title, 'Master Site'

# Location of sitemap file. '/' is relative to source directory.
set :sitemapDest, '/sitemap.html'

# Minify Javascript, boolean
set :minifyJavascript, true

###
# Layout
###
activate :LayoutGenerator

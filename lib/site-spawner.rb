class String
	# Unindent multiline string based on lowest amount of whitespace.
	def unindent
		gsub(/^#{scan(/^\s*/).min_by{|l|l.length}}/, "")
	end
end

module SiteSpawner
	# Require core library
	require "middleman-core"

	class LayoutGenerator < ::Middleman::Extension
		def initialize(app, options_hash={}, &block)
			super
			
			app.set(:layoutGen, self)
			
			require 'uglifier'
			
			stylesheets_dir = File.join(File.dirname(__FILE__), '..', 'styles')		
			Sass.load_paths << "#{stylesheets_dir}"
			
			def generateHead()
				app = @app
				stylesheets = ["stylesheet"]
				current_page = app.current_page
				title = current_page.parent ? " @ " + app.site_title : ""
				head = <<-HEAD.unindent
					<!DOCTYPE HTML>
					<html lang="en">
						<head>
							<meta charset="utf-8">
							<title>#{current_page.data.title + title if current_page.data.title}</title>
							#{app.stylesheet_link_tag "stylesheet"}
						</head>
				HEAD
				return head
			end

			def generateBefore
				app = @app
				current_page = app.current_page
				layout = ""
				layout << generateHead()

				# TODO: app.site_title needs to have all spaces replaced with &nbsp;
				# Otherwise it has to be selected to be white-space: nowrap;

				layout << <<-ERB.unindent
					<body>
						<header>
							<p>made at <a href="#{app.parent_url}">#{app.parent_title}</a></p>
							<div class="bar">
								#{app.link_to app.site_title, '/index.html'}
								#{ navigationGen() }
								<form method="get" action="http://www.google.com/search" class="search">
									<input type="search" name="q" placeholder="Search this site..." class="textfield" />
									<input type="submit" value="Search" class="button" />
									<input type="radio" name="sitesearch" value="web-polygraph.org" checked hidden class="hidden" />
								</form>
							</div>
						</header>
						<div class="content">
							#{ breadcrumbs() }
							<h1 class="contentHeader no_toc">#{current_page.data.title}</h1>
							#{ tocGen() }
				ERB
				return layout
			end
			
			def generateAfter()
				app = @app
				current_page = app.current_page
				childrenHtml = seeAlsoGen(5)
				sitemapDest = app.sitemapDest
				sitemapLink = app.link_to 'Sitemap', sitemapDest

				# XXX : For some unknown reason, find_resource_by_destination_path does not find sitemapDest
				sitemapLink = '' unless app.sitemap.find_resource_by_path(sitemapDest)
				layout = <<-ERB
							</div>
							<footer>
								<span class="see-also">
									#{"See Also:&nbsp;" + childrenHtml unless childrenHtml.empty?}
								</span>
								
								<span class="right-side">
									#{sitemapLink} &bull;
									#{app.link_to 'Help', '/support/index.html'}
									<br>
									&copy; #{Time.new.year} <a href="#{app.parent_url}">#{app.parent_title}</a>
								</span>
							</footer>
						</body>
					</html>
				ERB
				return layout
			end
			
			
			def generateMenuCurrentScript
				js = <<-MENUJS
					/*
					  Add 'current' class to menu item that links to current page,
					  or head of current page.
					  
					  Script does not support IE 9 and lower,
					  as well as Opera Mini, versions 5.0 through 7.0.
					  Source: http://caniuse.com/#feat=classlist
					*/
					var firstLevel = window.location.pathname.split( '/' )[1];
					[].forEach.call( document.querySelectorAll('.nav>ul>li>a'), function(el) {
						var elHref = el.href.split('/')[3];
						if (firstLevel == elHref) {
							// Never needs to be removed - removed on page reload.
							el.classList.add('current');
						}
					});
				MENUJS
				js = minifyJS(js)
				return js
			end
			
			
			def generateMenuHoverScript(time)
				js = <<-MENUJS
					/*
					  Script adds 'onHover' class to any 'li' item in '.nav'.
					  
					  Script does not support IE 9 and lower,
					  as well as Opera Mini, versions 5.0 through 7.0.
					  Source: http://caniuse.com/#feat=classlist
					*/
					var timeouts = [];
					var elements = [];
					function mouseOver(element) {
						element.classList.add('onHover');
						for (var i=0, len = timeouts.length; i < len; i++) {
							clearTimeout(timeouts[i]);
							elements[i].classList.remove('onHover');
						}
						timeouts = []; // Empty all instances of Array
						elements = [];
					};
					function mouseOut(element) {
						var menuElement = element,
						timeoutId = setTimeout(function(){
							menuElement.classList.remove('onHover');
						}, #{time});
						timeouts.push(timeoutId);
						elements.push(menuElement);
					}
					[].forEach.call( document.querySelectorAll('.nav li'), function(el) {
						el.addEventListener('mouseover', function(){mouseOver(el)}, false);
						el.addEventListener('mouseout',  function(){mouseOut(el) }, false);
					});
				MENUJS
				js = minifyJS(js)
				return js
			end
			
			def tocGen()
				sitemapHtml = getSitemapHtml(app.current_page);
				html = "<section class=\"toc\"><h3 class='no_number'>Sitemap</h3>#{sitemapHtml}</section>"
				return html if !sitemapHtml.empty?
			end

			
			# Helpers
			def sitemapGen()
				app = @app
				page = app.current_page
				while page.parent do
					page = page.parent
				end
				list = getSitemapHtml(page)
				return list
			end
			
			def navigationGen()
				return menuGen()
			end

			def menuGen()
				return app.Menu
			end

			# Generate one level of menu tree
			def menu(children)
				html = ''
				children.each do |child|
					html << child
				end
				return html
			end

			def getSitemapHtml(page)
				html = ""
				if page.children.length > 0 then
					html << "<ul>"
					children = page.children.sort_by{ |child| child.data.title.to_s rescue "" }
					children.each do |page|
						next if !page.data.title
						childHtml = getSitemapHtml(page)
						sitemapStr = "#{page.data.sitemap}"
						if (sitemapStr.empty? || sitemapStr == 'true' || sitemapStr == 'false') then
							sitemap = sitemapStr.empty? ? true : (sitemapStr == 'true')
							if sitemap then
								html << "<li>"
									html << "<a href=\"#{page.url}\">#{page.data.title}</a>"
									html << childHtml
								html << "</li>"
							end
						else
							raise SyntaxError, "#{child.path}: Expected a boolean value for 'sitemap' frontmatter variable, got '#{sitemapStr}'"
						end
					end
					html << "</ul>"
				end
				return html
			end
			
			def breadcrumbs()
				current_page = app.current_page
				crumbs = ""
				if current_page.parent && current_page.parent.parent then
					page = current_page
					while page.parent do
						if crumbs.empty? then
							crumbs = "<span>#{page.data.title}</span>"
						else
							crumbs = "#{app.link_to(page.data.title, page.url)} &raquo; #{crumbs}"
						end
						page = page.parent
					end
				end
				crumbs = "<div class=\"breadcrumbs\">#{crumbs}</div>\n" unless crumbs.empty?
				return crumbs
			end
			def seeAlsoGen(showAmount)
				page = app.current_page
				childrenList = ""
				children = page.children
					
				# Sort children by title
				children = children.sort_by{ |child| child.data.title.to_s }

				taken = 0
				
				children.each do |child|
					if taken >= showAmount then
						break
					end
					if child.data.title then
						alsoStr = "#{child.data.also}"
						if (alsoStr.empty? || alsoStr == 'true' || alsoStr == 'false') then
							also = alsoStr.empty? ? true : (alsoStr == 'true')
							if also then
								childrenList << ', ' if !childrenList.empty? # Seperator
								childrenList << app.link_to(child.data.title, child.url)
								taken = taken + 1
							end
						else
							raise SyntaxError, "#{child.path}: Expected a boolean value for 'also' frontmatter variable, got '#{alsoStr}'"
						end
					end
				end
				childrenList << "." if !childrenList.empty?  # period at end
				return childrenList
			end
			
			# Rendering Helpers
			def minifyJS(js)
				js = Uglifier.new.compile(js) if app.minifyJavascript
				return js
			end

			# Middleman Helpers
			app.helpers do
				def include(filename)
					if !filename.start_with?('/') then
						dirname = File.dirname(current_page.path)
						filename = "#{:source}/#{dirname}/#{filename}"
					end
					file = File.open(filename, "r")
					# Read whole file into content variable
					content = file.read
					file.close
					return content
				end
				def menu(*children)
					layoutGen.menu(children)
				end
				def roadpost(*args, &block)
					isMarkdown = current_page.source_file.include?('.md.')
					link = url_for(args[0])

					html = Tilt['markdown'].new { capture(*args, &block) }.render
					output = "<a href=\"#{ link }\" class=\"roadpost\">"
					output << html
					output << "</a>"


					# Prevent markdown from re-rendering its own output.
					if isMarkdown then
						output = "{::nomarkdown}\n" + output + "\n{:/nomarkdown}"
					end

					concat output
				end
			end
		end
	end
end

SiteSpawner::LayoutGenerator.register(:SiteSpawner)

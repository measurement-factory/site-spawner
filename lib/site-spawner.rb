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
			require 'yaml'
			
			stylesheets_dir = File.join(File.dirname(__FILE__), '..', 'styles')		
			Sass.load_paths << "#{stylesheets_dir}"
			
			def generateHead()
				app = @app
				stylesheets = ["stylesheet"]
				current_page = app.current_page

				cp_title = getTitle(current_page, 'title-head')

				title = current_page.parent ? " @ " + app.site_spawner[:site_title] : ""
				head = <<-HEAD.unindent
					<!DOCTYPE HTML>
					<html lang="en">
						<head>
							<meta charset="utf-8">
							<title>#{cp_title + title}</title>
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
							<p>#{app.site_spawner[:byLine]}</p>
							<div class="bar">
								#{app.link_to app.site_spawner[:site_title], '/index.html'}
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
							<h1 class="contentHeader no_number">#{getTitle(current_page, 'title-body')}</h1>
							#{ tocGen() }
				ERB
				return layout
			end
			
			def generateAfter()
				app = @app
				current_page = app.current_page
				childrenHtml = seeAlsoGen(5)
				sitemapDest = app.site_spawner[:sitemapLocation]
				sitemapLink = app.link_to 'Sitemap', sitemapDest

				# XXX : For some unknown reason, find_resource_by_destination_path does not find sitemapLink
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
									&copy; #{Time.new.year} <a href="#{app.site_spawner[:parent_url]}">#{app.site_spawner[:parent_title]}</a>
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
				sitemapHtml = getSitemapHtml(app.current_page, 'title-toc');
				html = "<section class=\"toc\"><h3 class='no_number'>Sitemap</h3>#{sitemapHtml}</section>"
				return html unless sitemapHtml.empty?
			end

			
			# Helpers
			def sitemapGen()
				app = @app
				page = app.current_page
				while page.parent do
					page = page.parent
				end
				list = getSitemapHtml(page, 'title-sitemap')
				return list
			end
			
			def navigationGen()
				return menuGen()
			end

			def menuGen()
				return app.site_spawner[:menu]
			end

			# Generate one level of menu tree
			def menu(children)
				html = ''
				children.each do |child|
					html << child
				end
				return html
			end

			def getSitemapHtml(page, title)
				html = ""
				if page.children.length > 0 then
					html << "<ul>"
					
					children = page.children
					children = children.sort_by { |child| getTitle(child, title) rescue "" }

					children.each do |page|
						next if !getTitle(page, title)
						childHtml = getSitemapHtml(page, title)
						sitemapStr = "#{page.data.sitemap}"
						if (sitemapStr.empty? || sitemapStr == 'true' || sitemapStr == 'false') then
							sitemap = sitemapStr.empty? ? true : (sitemapStr == 'true')
							if sitemap then
								html << "<li>"
									html << "<a href=\"#{page.url}\">#{getTitle(page, title)}</a>"
									html << childHtml
								html << "</li>"
							end
						else
							logger.error "#{child.path}: Expected a boolean value for 'sitemap' frontmatter variable, got '#{sitemapStr}'"
						end
					end
					html << "</ul>"
				end
				return html
			end
			
			def breadcrumbs
				current_page = app.current_page
				crumbs = ""
				if current_page.parent && current_page.parent.parent then
					page = current_page
					while page.parent do
						if crumbs.empty? then
							crumbs = "<span>#{ getTitle(page, 'title-breadcrumbs') }</span>"
						else
							crumbs = "#{app.link_to(getTitle(page, 'title-breadcrumbs'), page.url)} &raquo; #{crumbs}"
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
				children = children.sort_by { |child| getTitle(child, 'title-seealso') }

				taken = 0
				
				children.each do |child|
					if taken >= showAmount then
						break
					end
					if getTitle(child, 'title-seealso') then
						alsoStr = "#{child.data.also}"
						if (alsoStr.empty? || alsoStr == 'true' || alsoStr == 'false') then
							also = alsoStr.empty? ? true : (alsoStr == 'true')
							if also then
								childrenList << ', ' if !childrenList.empty? # Seperator
								childrenList << app.link_to(getTitle(child, 'title-seealso'), child.url)
								taken = taken + 1
							end
						else
							logger.error "#{child.path}: Expected a boolean value for 'also' frontmatter variable, got '#{alsoStr}'"
						end
					end
				end
				childrenList << "." if !childrenList.empty?  # period at end
				return childrenList
			end

			def getTitle(page, needTitle)
				titles = %w(title title-head title-body title-seealso title-sitemap title-toc title-breadcrumbs)
				title = page.data["#{needTitle}"]

				index = titles.index "#{needTitle}"

				while title == nil do
					index = index - 1
					title = page.data["#{titles[index]}"]
					if index == 0 && title == nil then
						return ''
					end
				end

				return title
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
				def csvToRows(file, regex=nil)
					resource = sitemap.find_resource_by_path(file)
					if resource == nil then
						logger.error "Cannot find #{file} while processing #{current_page.path}."
						return ''
					end
					path = resource.source_file
					table = ''

					lines = CSV.read(path)

					if lines.length == 0 then
						logger.error "Empty CSV file: #{file} while processing #{current_page.path}."
					end
					
					lines.each do |row|
						if regex != nil then
							if row[0] !~ %r@#{regex}@ then
								next
							end
						end
						row.each do |cell|
							table << "|#{cell}"
						end
						table << "|"
						table << "\n"
					end

					if table.empty? then
						logger.error "No #{file} rows match regex: #{regex} while processing #{current_page.path}."
					end

					return table
				end
				def tooltip(name)
					resource = sitemap.find_resource_by_path(name)
					if resource == nil then
						logger.error "Cannot find tooltip resource #{name} while processing #{current_page.path}."
						return ''
					end
					title = resource.data['tooltip']
					if title == nil then
						logger.error 'Missing tooltip for ' + name + " while processing #{current_page.path}."
						title = ''
					end
					href = resource.url
					return "<sup><a title=\"#{title}\" href=\"#{href}\">**</a></sup>"
				end
				def lxTableHeader(options={})
					table = ''
					options[:columns].each do |column|
						table << "#{column[:name]}|"
					end

					return table
				end
				def lxTableRow(options={})
					file = "#{:source}/#{options[:file]}"
					yaml = YAML.load_file(file)
					table = ""

					options[:columns].each do |column|
						table << lxValue(:column => column, :file => options[:file]) + '|'
					end

					return table
				end
				def lxValue(options = {})
					options[:file] = "#{:source}/#{options[:file]}"
					yaml = YAML.load_file(options[:file])

					column = options[:column]

					data = yaml["#{column[:key]}"]

					default_format = '%s'

					if data.is_a? Numeric then
						if column[:round_to_nearest] == nil then
							column[:round_to_nearest] = 1
						end

						data_sign = data >= 0 ? +1 : -1

						rounding = column[:round_to_nearest] * data_sign

						data = ((data.to_f + rounding/2.0)/rounding).floor*rounding

						default_format = '%d'
					end

					if column[:format] == nil then
						column[:format] = default_format
					end
				
					begin
						data = column[:format] % data
					rescue
						logger.error("#{current_page.source_file}: Incompatible cell format #{column[:format]} when printing #{data}.")
					end

					return data
				end
				def url_for(path_or_resource, options = {})
					if current_page != nil && !in_sitemap?(path_or_resource) then
						path = ''
						if path_or_resource.is_a?(::Middleman::Sitemap::Resource) then
							path = path_or_resource.path
						else
							path = path_or_resource
						end
						if !path.include?('.css') && path !~ %r@^[\d\w\S]*?://@ then
							logger.error "#{current_page.path}: url_for did not find resource '#{path}'"
						end
					end
					
					super
				end
				def in_sitemap?(path_or_resource)
					url = ''
					if path_or_resource.is_a?(::Middleman::Sitemap::Resource) then
						url = path_or_resource.url
					else
						url = path_or_resource
					end

					if url =~ %r@^/.*?/$@ then
						url = url + 'index.html'
					end
					return sitemap.find_resource_by_destination_path(url) != nil
				end
			end
		end
	end
end

SiteSpawner::LayoutGenerator.register(:SiteSpawner)

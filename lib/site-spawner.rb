class String
	# Unindent multiline string based on lowest amount of whitespace.
	def unindent
		gsub(/^#{scan(/^\s*/).min_by { |l|l.length }}/, '')
	end
end

module SiteSpawner
	# Require middleman core library
	require 'middleman-core'

	class LayoutGenerator < ::Middleman::Extension
		def initialize(app, options_hash = {}, &block)
			super

			app.config[:layoutGen] = self

			require 'uglifier'
			require 'yaml'

			stylesheets_dir = File.join(File.dirname(__FILE__), '..', 'styles')
			app.config[:sass_assets_paths].push(stylesheets_dir).uniq!

			app.after_configuration do
				sprockets.append_path( File.join(File.dirname(__FILE__), '..', 'javascripts'))
				["dist/jquery.min.js",
					"dist/jquery.jqplot.min.js",
					"dist/plugins/jqplot.highlighter.min.js",
					"dist/plugins/jqplot.cursor.min.js",
					"dist/plugins/jqplot.enhancedLegendRenderer.min.js",
					"dist/plugins/jqplot.dateAxisRenderer.min.js",
					"dist/plugins/jqplot.canvasTextRenderer.min.js",
					"dist/plugins/jqplot.canvasAxisLabelRenderer.min.js",
					"client.js",
					"dist/jquery.jqplot.min.css"
				].each do |file|
					sprockets.import_asset file
				end
			end

			def generateHead()
				app = @app
				current_page = app.current_page

				title = getTitle(current_page, 'title-head')

				if current_page.data['title_head_suffix'] then
					suffix = current_page.data['title_head_suffix']
				elsif app.site_spawner[:title_head_suffix] then
					suffix = app.site_spawner[:title_head_suffix]
				else
					suffix = app.site_spawner[:site_title]
				end
				title = title + (current_page.parent ? ' @ ' << suffix : '')

				classes = []

				if current_page.data['header_numbering'] then
					classes.push 'header_numbering'
				end

				head_str = ''
				head_str << current_page.data['head-content'] unless current_page.data['head-content'].nil?
				head_str << app.site_spawner[:head_content] unless app.site_spawner[:head_content].nil?

				if !current_page.data['js'].nil? then
					current_page.data['js'].each do |js|
						head_str << app.javascript_include_tag(js)
					end
				end

				if !current_page.data['css'].nil? then
					current_page.data['css'].each do |style|
						head_str << app.stylesheet_link_tag(style)
					end
				end

				if !current_page.data['jqplot'].nil? then
					jqplot = current_page.data['jqplot']
					if jqplot == true then
						jsfiles = ["dist/jquery.min.js",
							"dist/jquery.jqplot.min.js",
							"dist/plugins/jqplot.enhancedLegendRenderer.min.js",
							"dist/plugins/jqplot.dateAxisRenderer.min.js",
							"dist/plugins/jqplot.canvasTextRenderer.min.js",
							"dist/plugins/jqplot.canvasAxisLabelRenderer.min.js",
							"dist/plugins/jqplot.highlighter.min.js",
							"dist/plugins/jqplot.cursor.min.js",
							"client.js"]

						jsfiles.each do |file|
							head_str << app.javascript_include_tag(file)
						end

						css = "/javascripts/dist/jquery.jqplot.min.css"
						head_str << '<link rel="stylesheet" href="' << css << '" />'
					elsif jqplot != false then
						logger.error(current_page.source_file << ": Unrecognized jqplot value " << jqplot << ", should be a boolean.")
					end
				end

				head = <<-HEAD.unindent
					<!DOCTYPE HTML>
					<html lang="en" class="#{classes.join(' ')}">
						<head>
							<meta charset="utf-8">
							<title>#{title}</title>
							#{app.stylesheet_link_tag 'stylesheet'}
							#{head_str}
						</head>
				HEAD
				return head
			end

			def generateBefore
				app = @app
				current_page = app.current_page
				layout = ''
				layout << generateHead()

				site_title = app.site_spawner[:site_title].gsub("\s", '&nbsp;')

				layout << <<-ERB.unindent
					<body>
						<header>
							<p><span class="left">#{app.site_spawner[:byLine]}</span>
							<span class="right" id="changer">#{ app.site_spawner[:fader_text][0] unless app.site_spawner[:fader_text].nil? }</span></p>
							<div class="bar">
								#{app.link_to site_title, '/index.html'}
								#{ navigationGen() }
								<form method="get" action="http://www.google.com/search" class="search">
									<input type="search" name="q" placeholder="Search this site..." class="textfield" />
									<input type="submit" value="Search" class="button" />
									<input type="radio" name="sitesearch" value="#{app.site_spawner[:search_scope]}" checked hidden class="hidden" />
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

				sitemapLink = ''
				help = ''

				unless app.site_spawner[:sitemapLocation].nil? then
					sitemapDest = app.site_spawner[:sitemapLocation]
					sitemapLink = app.link_to 'Sitemap', sitemapDest
				end

				unless app.site_spawner[:helpLocation].nil? then
					help = app.link_to 'Help', app.site_spawner[:helpLocation]
				end

				unless sitemapLink.empty? && help.empty? then
					sitemapLink = "#{sitemapLink} &bull;"
				end

				parent_title = app.site_spawner[:parent_title].gsub("\s", '&nbsp;') # Replace all whitespaces with &nbsp; to prevent wrapping.
				copyright = "&copy;&nbsp;#{Time.new.year}&nbsp;" << app.link_to(parent_title, app.site_spawner[:parent_url])

				disqus = <<-HTML.unindent
					<div class="seperator"></div>
					<div id="disqus_thread"></div>
					<script type="text/javascript">
					    var disqus_shortname = '#{app.site_spawner[:disqus_shortname]}';

					    (function() {
					        var dsq = document.createElement('script'); dsq.type = 'text/javascript'; dsq.async = true;
					        dsq.src = '//' + disqus_shortname + '.disqus.com/embed.js';
					        (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(dsq);
					    })();
					</script>
					<noscript>Please enable JavaScript to view the <a href="http://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
					<a href="http://disqus.com" class="dsq-brlink">blog comments powered by <span class="logo-disqus">Disqus</span></a>
				HTML

				layout = <<-ERB
							</div>
							#{ disqus if !current_page.data['disqus'].nil? && current_page.data['disqus'] == true }
							<footer>
								<span class="see-also">
									#{'See Also:&nbsp;' + childrenHtml unless childrenHtml.empty?}
								</span>
								<span class="right-side">
									#{sitemapLink}
									#{ help }
									<br>
									#{ copyright }
								</span>
							</footer>
						</body>
						#{ generateFaderScript(app.site_spawner[:fader_text]) if !app.site_spawner[:fader_text].nil? && app.site_spawner[:fader_text].length > 1 }
					</html>
				ERB
				return layout
			end

			def generateFaderScript(arr)
				js = <<-FADEJS
					var time = (60 + 2)*1000 // 60 seconds, 2 seconds for fading.
					var el = document.getElementById('changer');
					var text = #{ arr.inspect };

					function update() {
						el.classList.add('fadeOut');
						setTimeout(showText, 1000); // 1 second for fadeOut.
					}

					function showText() {
						var newtext = text[Math.floor(Math.random()*text.length)];
						el.innerHTML = newtext;
						el.classList.remove('fadeOut');
					}

					setInterval(update, time);
				FADEJS
				js = "<script> #{js} </script>"
				return js
			end

			def tocGen()
				if !app.current_page.data['generate-toc'].nil? && app.current_page.data['generate-toc'] == false then
					return ''
				end
				sitemapHtml = getSitemapHtml(app.current_page, 'title-toc')
				html = "<section class=\"toc\"><h3 class='no_number'>Table of Contents</h3>#{sitemapHtml}</section>"
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
				html = ''
				if page.children.length > 0 then
					html << '<ul>'

					children = page.children
					children = children.sort_by { |child| getTitle(child, title) }

					children.each do |child|
						child_title = getTitle(child, title)
						next if child_title.empty?
						childHtml = getSitemapHtml(child, title)
						sitemapStr = "#{child.data.sitemap}"
						if (sitemapStr.empty? || sitemapStr == 'true' || sitemapStr == 'false') then
							sitemap = sitemapStr.empty? ? true : (sitemapStr == 'true')
							if sitemap then
								html << '<li>'
									html << app.link_to(child_title, child.url)
									html << childHtml
								html << '</li>'
							end
						else
							app.logger.error "#{child.path}: Expected a boolean value for 'sitemap' frontmatter variable, got '#{sitemapStr}'"
						end
					end
					html << '</ul>'
				end

				# If all children get skipped due to their title being empty,
				# we need to still return an empty string. This handles that.
				return '' if html == '<ul></ul>'

				return html
			end

			def breadcrumbs
				current_page = app.current_page
				crumbs = ''
				if current_page.parent && current_page.parent.parent then
					page = current_page
					while page.parent do
						page_title = getTitle(page, 'title-breadcrumbs')

						if crumbs.empty? then
							crumbs = '<span>' << page_title << '</span>'
						else
							crumbs = "#{app.link_to(page_title, page.url)} &raquo; #{crumbs}"
						end
						page = page.parent
					end
				end
				crumbs = "<div class=\"breadcrumbs\">#{crumbs}</div>\n" unless crumbs.empty?
				return crumbs
			end

			def seeAlsoGen(showAmount)
				page = app.current_page
				childrenList = ''
				children = page.children

				# Sort children by title
				children = children.sort_by { |child| getTitle(child, 'title-seealso') }

				taken = 0

				children.each do |child|
					if taken >= showAmount then
						break
					end

					child_title = getTitle(child, 'title-seealso')

					unless child_title.empty? then
						alsoStr = "#{child.data.also}"
						if (alsoStr.empty? || alsoStr == 'true' || alsoStr == 'false') then
							also = alsoStr.empty? ? true : (alsoStr == 'true')
							if also then
								childrenList << ', ' unless childrenList.empty? # Seperator
								childrenList << app.link_to(child_title, child.url)
								taken = taken + 1
							end
						else
							app.logger.error "#{child.path}: Expected a boolean value for 'also' frontmatter variable, got '#{alsoStr}'"
						end
					end
				end
				childrenList << '.' unless childrenList.empty?  # period at end
				return childrenList
			end

			def getTitle(page, needTitle)
				titles = %w(title title-head title-body title-seealso title-sitemap title-toc title-breadcrumbs)
				title = page.data["#{needTitle}"]

				index = titles.index "#{needTitle}"

				while title.nil? do
					index = index - 1
					title = page.data["#{titles[index]}"]
					if index == 0 && title.nil? then
						if !page.binary? && !page.ignored? then
							app.logger.error "#{page.source_file}: Could not find any titles in frontmatter."
						end
						return ''
					end
				end

				return title
			end

			# Rendering Helpers
			def minifyJS(js)
				js = Uglifier.new.compile(js) if app.site_spawner[:minifyJavascript]
				return js
			end

			# Callbacks
			app.ready do
				resources = sitemap.resources
				app.site_spawner[:iterating_sitemap] = true
				resources.each do |resource|
					next if resource.binary?
					self.current_path = nil # Reset path because nobody else will.
					begin
						resource.render
					rescue
						error = resource.source_file << ": Failed to render resource: #{$ERROR_INFO}"
						logger.error(error)
					end
					self.current_path = nil # Reset path because nobody else will.
				end
				app.site_spawner[:iterating_sitemap] = false
			end

			# Middleman Helpers
			app.helpers do
				def include(filename)
					unless filename.start_with?('/') then
						dirname = File.dirname(current_page.path)
						filename = "#{:source}/#{dirname}/#{filename}"
					end
					file = File.open(filename, 'r')
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
					output << '</a>'

					# Prevent markdown from re-rendering its own output.
					if isMarkdown then
						output = "{::nomarkdown}\n" + output + "\n{:/nomarkdown}"
					end

					concat output
				end

				def csvToRows(file, regex = nil)
					resource = sitemap.find_resource_by_path(file)
					if resource.nil? then
						logger.error "Cannot find #{file} while processing #{current_page.source_file}."
						return ''
					end
					path = resource.source_file
					table = ''

					lines = CSV.read(path)

					if lines.length == 0 then
						logger.error "Empty CSV file: #{file} while processing #{current_page.source_file}."
					end

					lines.each do |row|
						if regex.nil? then
							if row[0] !~ /#{regex}/ then
								next
							end
						end
						row.each do |cell|
							table << "|#{cell}"
						end
						table << '|'
						table << "\n"
					end

					if table.empty? then
						logger.error "No #{file} rows match regex: #{regex} while processing #{current_page.source_file}."
					end

					return table
				end

				def tooltip(name)
					resource = sitemap.find_resource_by_destination_path(name)
					if resource.nil? then
						logger.error "Cannot find tooltip resource #{name} while processing #{current_page.source_file}."
						return ''
					end
					title = resource.data['tooltip']
					if title.nil? then
						logger.error "#{resource.source_file}: missing tooltip. Needed by #{current_page.source_file}."
						title = ''
					end
					href = resource.url
					return "<sup><a title=\"#{title}\" href=\"#{href}\">**</a></sup>"
				end

				def getYAML(options = {})
					unless options[:files].nil? && options[:file].nil? then
						logger.error "#{current_page.source_file}: :files and :file options are mutually exclusive."
					end

					if options[:files].nil? then
						files = [options[:file]]
					else
						if options[:files].is_a? Array then
							files = options[:files]
						else
							logger.error "#{current_page.source_file}: Option :files should be an Array."
							files = [options[:files]]
						end
					end

					yaml = {}

					files.each do |file|
						if in_sitemap?(file) then
							file = "#{:source}/#{file}"
							yaml_part = YAML.load_file(file)
							yaml.merge!(yaml_part)
						else
							logger.error "#{current_page.source_file}: getYAML() did not find #{file} in sitemap."
						end
					end

					return yaml
				end

				def lxTableHeader(options = {})
					table = ''
					options[:columns].each do |column|
						data = column[:name]

						unless column[:tooltip].nil? then
							data << tooltip(column[:tooltip])
						end

						# Add in unit if it exists.
						unless column[:unit].nil? then
							data = getUnit(data, column[:unit], 'thead')
						end

						table << "#{data}|"
					end

					return table
				end

				def getUnit(value, unit, style)
					if style == 'none' then
						return value
					elsif style == 'thead' then
						unless (unit =~ /^\s+/).nil? then
							unit = unit.gsub(/^\s+/, '')
						end
						value = value + '<br>'
						value = value + "(#{unit})"
					elsif style == 'suffix' then
						unless (unit =~ /^\s+/).nil? then
							unit = unit.gsub(/^\s+/, '')
							value << '&nbsp;'
						end
						value << unit
					else
						logger.error "#{current_page.source_file}: Could not find get value with unkown :unit_style: #{style}."
						return value
					end
				end

				def lxTableRow(options = {})
					if options[:yaml].nil? then
						yaml = getYAML(options)
					else
						yaml = options[:yaml]
					end

					table = ''

					options[:columns].each do |column|
						table << lxValue(column: column, yaml: yaml, unit_style: 'none') + '|'
					end

					return table
				end

				def lxValue(options = {})
					if options[:yaml].nil? then
						yaml = getYAML(options)
					else
						yaml = options[:yaml]
					end

					if options[:column].nil? && !options[:columns].nil? then
						logger.error "#{current_page.source_file}: Use :column, not :columns with lxValue()."
						column = options[:columns]
					else
						column = options[:column]
					end

					if column.nil? then
						logger.error "#{current_page.source_file}: lxValue() was given an invalid column."
						return ''
					end

					if column[:key].nil? then
						logger.error "#{current_page.source_file}: Did not specify column key."
						return ''
					end

					data = yaml[column[:key]]

					if data.nil? then
						logger.error "#{current_page.source_file}: Could not find lx value #{column[:key]}."
						return ''
					end

					default_format = '%s'

					if data.is_a? Numeric then
						if column[:round_to_nearest].nil? then
							column[:round_to_nearest] = 1
						end

						data_sign = data >= 0 ? +1 : -1

						rounding = column[:round_to_nearest] * data_sign

						data = ((data.to_f + rounding / 2.0) / rounding).floor * rounding

						default_format = '%d'

						unless column[:scale].nil? then
							data = data.to_f / column[:scale].to_f
						end
					end

					if column[:format].nil? then
						column[:format] = default_format
					end

					begin
						data = column[:format] % data
					rescue
						logger.error("#{current_page.source_file}: Incompatible cell format #{column[:format]} when printing #{data}.")
					end

					unless column[:unit].nil? then
						if options[:unit_style] then
							data = getUnit(data, column[:unit], options[:unit_style])
						else
							data = getUnit(data, column[:unit], 'suffix')
						end
					end

					return data
				end

				def url_for(path_or_resource, options = {})
					if !current_page.nil? && in_sitemap?(path_or_resource) then
						path = ''
						if path_or_resource.is_a?(::Middleman::Sitemap::Resource) then
							path = path_or_resource.path
						else
							path = path_or_resource
						end
						if !path.include?('.css') && path !~ %r@^[\d\w]*?://@ && !path.include?('#') then
							logger.error "#{current_page.source_file}: url_for did not find resource '#{path}'"
						end
					end

					if site_spawner[:iterating_sitemap] == true then
						site_spawner[:pages] ||= {}
						if path_or_resource.is_a?(::Middleman::Sitemap::Resource) then
							resource = path_or_resource
						else
							if path_or_resource =~ %r@/$@ then
								path_or_resource << 'index.html'
							end
							resource = sitemap.find_resource_by_destination_path(path_or_resource)
							resource ||= sitemap.find_resource_by_path(path_or_resource)
						end

						if !resource.nil? && !resource.binary? then
							logger.debug "#{current_resource.source_file}: processing link to #{resource.source_file}."
							site_spawner[:pages][resource.source_file] ||= {}
							site_spawner[:pages][resource.source_file][current_resource.source_file] = current_resource
							resource_hash = site_spawner[:pages][resource.source_file]
							logger.debug "#{resource.source_file}: New keys list #{resource_hash.keys}."
						end
					end

					super
				end

				def link_to(*args, &block)
					url_arg_index = block_given? ? 0 : 1
					options_index = block_given? ? 1 : 2
					url = args[url_arg_index]
					options = args[options_index] || {}

					if !in_sitemap?(url) && url !~ %r@^[\d\w]*?://@ && !url.include?('#') then
						options.merge!(class: 'future', title: 'TBD')
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

					in_sitemap = sitemap.find_resource_by_destination_path(url).nil?

					if ignore_manager.ignored?(url) then
						in_sitemap = true # XXX: Hacky way of saying that ignored resources should not throw an error.
					end

					return in_sitemap
				end
			end
		end
	end
end

SiteSpawner::LayoutGenerator.register(:SiteSpawner)

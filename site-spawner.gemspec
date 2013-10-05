Gem::Specification.new do |s|
  s.name        = 'site-spawner'
  s.version     = '0.0.1'
  s.date        = "2013-10-05"
  s.summary     = "Helps create a set of similar websites associated with a single parent organization."
  s.description = <<-DESC
      Site Spawner is useful for making multiple project or product 
      sites that have independent content but share similar layouts,
      styles, navigation capabilities, etc.

      This project uses Middleman for individual site generation.

      Site Spawner behavior can be adjusted by overriding 
      SiteSpawner::LayoutGenerator methods.
    DESC
  s.authors     = ['Mark Simulacrum', 'Alex Rousskov']
  s.email       = 'info@measurement-factory.com'
  s.files      += Dir.glob("styles/*")
  s.files      += Dir.glob("lib/*")
  s.files      += Dir.glob("bin/*")
  s.homepage    = 'https://github.com/measurement-factory/site-spawner/'
  s.license     = 'MIT'
  
  s.executable = "site-spawner"
  
  s.add_dependency("middleman")
  
  # JS Compression
  s.add_dependency("uglifier")
  s.add_dependency("therubyracer")

  # Stylesheets
  s.add_dependency("sass")
  s.add_dependency("compass")
end

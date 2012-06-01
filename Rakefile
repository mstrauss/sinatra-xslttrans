begin
  require "vlad"
  # Vlad.load(:app => nil, :scm => "git")
  Vlad.load(:app => nil)
rescue LoadError
  # do nothing
end


task :default => [:doc]

task :doc do
  sh 'yard doc app.rb --private'
end

task :run do
  sh 'bundle exec env RACK_ENV=production ruby app.rb'
end

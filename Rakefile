require 'echoe'

Echoe.new("s3upload","0.1.0") do |p|
  p.author = "Robert Sköld"
  p.summary = "A jQuery plugin for direct upload to an Amazon S3 bucket."
  p.url = "http://github.com/slaskis/s3upload"
  p.runtime_dependencies = []
end

task :build do
  sh "haxe -cp src/hx -main S3Upload -swf test/public/s3upload.swf -swf-version 9"
end
require "rubygems"
require "sinatra"
require "aws/s3"
require "s3upload"

set :static, true

get "/s3upload" do
  up = S3::Upload.new( ENV["S3_KEY"] , ENV["S3_SECRET"] ,  "osb-s3upload")
  up.to_xml( params[:key] , params[:contentType] )
end

get "/" do
  haml :index
end
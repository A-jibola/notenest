Cloudinary.config do |config|
  config.cloud_name = ENV["CLOUDINARY_CLOUDNAME"]
  config.api_key = ENV["CLOUDINARY_APIKEY"]
  config.api_secret = ENV["CLOUDINARY_APISECRET"]
end

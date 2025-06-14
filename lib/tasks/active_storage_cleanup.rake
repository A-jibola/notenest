namespace :manage_storage do
  desc "Removing unattached blobs from Cloudinary"

  task purge_unattached: :environment do
    puts "Looking for unattached  blobs ..."

    count = 0
    ActiveStorage::Blob.unattached.find_each do |blob|
      puts "Purging blob: #{blob.filename}"
      blob.purge
      count+=1
    end
    puts "Done!. #{count} blobs purged"
  end
end

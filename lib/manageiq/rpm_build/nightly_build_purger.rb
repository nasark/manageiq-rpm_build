module ManageIQ
  module RPMBuild
    class NightlyBuildPurger
      include S3Common

      def run
        candidates = {}
        keepers    = {}

        client.list_objects(:bucket => OPTIONS.rpm_repository.s3_api.bucket, :prefix => File.join("builds", "manageiq-nightly")).flat_map(&:contents).each do |object|
          package, timestamp    = package_timestamp_from_key(object.key)
          candidates[package] ||= []
          keepers[package]    ||= []

          if recent?(timestamp)
            keepers[package] << object.key
            next
          end

          position = (timestamp.to_i - 20_000_000_000_000) / 10_000 # YYMMDDHH i.e. 22091300
          candidates[package][position] = object.key
        end

        candidates.each_key do |package|
          # Keep the most recent 14 nightly builds of any package
          (candidates[package].compact[0..-14] - keepers[package]).each { |i| delete(i) }
        end
      end

      private

      def delete(key)
        print "Deleting #{key}... "
        client.delete_object(:bucket => OPTIONS.rpm_repository.s3_api.bucket, :key => key)
        puts "done."
      end

      def now
        @now ||= Time.now.utc
      end

      def package_timestamp_from_key(key)
        key.match(/.*\/(.*)-.*(\d{14}).*/).captures
      end

      def recent?(timestamp)
        require 'date'
        # Keep anything 2.weeks or newer
        (now - DateTime.parse(timestamp).to_time) < 1209600
      end
    end
  end
end

require 'hapgood/attach/sources/io'
require 'fileutils'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed File sources/sinks.
      class File < Hapgood::Attach::Sources::IO
        FMASK = 0644
        DMASK = 0755

        attr_reader :uri

        def self.load(file, metadata = {})
          pathname = Pathname.new(file.path)
          path = URI.encode(pathname.realpath.to_s)
          uri = URI.parse('file://localhost/').merge(path)
          self.new(uri, metadata)
        end

        # Create a new File at the given URI and store the given source in it.
        def self.store(source, uri)
          p = Pathname(uri.path)
          FileUtils.mkdir_p(p.dirname, :mode => DMASK)
          raise "Target file already exists! (#{p}) " if p.exist?
          FileUtils.cp(source.tempfile.path, uri.path)
          p.chmod(FMASK) if FMASK
          self.new(uri, source.metadata)
        end

        # Reload a persisted source
        def self.reload(uri, metadata = {})
          self.new(uri, metadata)
        end

        def self.aspect_data(uri, aspect_name)
        end

        def initialize(uri, m = {})
          @uri = uri
          super
        end

        def valid?
          !!file
        rescue MissingSource => e
          @error = e.to_s
          false
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          true
        end

        # Can this source be modified by this application?
        def readonly?
          frozen?
        end

        # =Metadata=
        # Returns a file name suitable for this source when saved in a persistent file.
        # This is a fallback as the basename can be cryptic in many case.
        def filename
          @metadata[:filename] || pathname.basename.to_s
        end

        # As a fallback, guess at the MIME type of the file using the extension.
        def mime_type
          @metadata[:mime_type] || Mime::Type.lookup_by_extension(pathname.extname[1..-1])
        end

        def last_modified
          pathname.mtime
        end

        # =Data=
        def pathname
          @pathname ||= Pathname.new(URI.decode(uri.path))
        end

        def blob
          io.rewind
          io.read
        end

        # Returns a closed Tempfile of source's data.
        def tempfile
          ::Tempfile.new(filename, tempfile_path).tap do |tmp|
            tmp.close
            ::FileUtils.cp(pathname.to_s, tmp.path)
          end
        end

        def io
          file
        end

        # =State Transitions=
        def destroy
          pathname.delete
        rescue Errno::ENOENT
        ensure
          freeze
        end

        # destroy the related aspect
        def destroy_aspect(filename)
          # not yet implemented.
        end

        private
        def file
          pathname.open
        rescue Errno::ENOENT => e
          raise MissingSource, e.to_s
        end
      end
    end
  end
end
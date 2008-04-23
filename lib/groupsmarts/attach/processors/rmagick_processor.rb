require 'RMagick'
module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Processors
      module RmagickProcessor
        def self.included(base)
          base.send :extend, ClassMethods
          base.alias_method_chain :process_attachment, :processing
        end
        
        module ClassMethods
          # Yields a block containing an RMagick Image for the given binary data.
          def with_image(file, &block)
            begin
              # NB: Magick::Image#read is too stupid to handle Tempfiles (much less CGI Uploads) so we need to pass a path string instead.
              binary_data = file.is_a?(Magick::Image) ? file : Magick::Image.read(file.path).first unless !Object.const_defined?(:Magick)
            rescue
              # Log the failure to load the image.  This should match ::Magick::ImageMagickError
              # but that would cause acts_as_attachment to require rmagick.
              logger.debug("Exception working with image: #{$!}")
              binary_data = nil
            end
            block.call binary_data if block && binary_data
          ensure
            !binary_data.nil?
          end
        end

      protected
        def process_attachment_with_processing
          return unless process_attachment_without_processing
          with_image do |img|
            resize_image(img, resize) if resize
            self.width  = img.columns if respond_to?(:width)
            self.height = img.rows    if respond_to?(:height)
            img.strip! if self.thumbnail?
            callback :after_resize
          end if image?
        end
      
        # Performs the actual resizing operation for a thumbnail
        def resize_image(img, size)
          size = size.first if size.is_a?(Array) && size.length == 1 && !size.first.is_a?(Fixnum)
          if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
            size = [size, size] if size.is_a?(Fixnum)
            img.thumbnail!(*size)
          else
            img.change_geometry(size.to_s) { |cols, rows, image| image.resize!(cols, rows) }
          end
          update_source(GroupSmarts::Attach::Sources::Rmagick.new(img, source, thumbnail))
        end
      end
    end
  end
end
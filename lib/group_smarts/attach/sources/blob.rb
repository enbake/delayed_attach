module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for blob sources
      class Blob < GroupSmarts::Attach::Sources::Base
        # =Metadata=
        
        # =Data=
        # Return the source's data as a blob.
        def blob
          @data
        end
      end
    end
  end
end
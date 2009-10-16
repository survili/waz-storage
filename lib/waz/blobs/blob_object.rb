module WAZ
  module Blobs
    # This class is used to model the Blob inside Windows Azure Blobs the usage
    # it's pretty simple, here you can see a couple of samples. These are the implemented methods of the blob API up to now. 
    # The basics are implemented although blocks management is not yet completed, I consider that the API is pretty usable since 
    # it covers the basics
    #
    #   # retrieve blob name, uri and content-type
    #   blob.name
    #   blob.url
    #   blob.content_type
    #
    # 	# retrieve blob value 
    #   blob.value #=> lazy loaded payload of the blob
    #
    #   # retrieve blob metadata (+ properties)
    #   blob.metadata #=> hash containing beautified metadata (:x_ms_meta_name)
    #   
    #   # put blob metadata
    #   blob.put_properties(:x_ms_meta_MyProperty => "my value") 
    #
    # 	# update value
    #   blob.value = "my new value" #=> this will update the blob content on WAZ
    #
    # *REMARKS*: This class is not meant to be manually instanciated it's basicaly an internal 
    # representation returned by the WAZ::Blobs::Container.
    class BlobObject      
      class << self
        # This method is internally used by this class. It's the way we keep a single instance of the 
        # service that wraps the calls the Windows Azure Blobs API. It's initialized with the values
        # from the default_connection on WAZ::Storage::Base initialized thru establish_connection!
        def service_instance
          @service_instance ||= Service.new(WAZ::Storage::Base.default_connection.merge(:type_of_service => "blob"))
        end        
      end
      
      attr_accessor :name, :url, :content_type
      
      # Creates a new instance of the Blob object. This constructor is internally used by the Container
      # it's initialized thru a hash that's received as parameter. It has the following requirements:
      # <em>:name</em> which is the blob name (usually the file name), <em>:url</em> that is the url of the blob (used to download or access it via browser) 
      # and <em>:content_type</em> which is the content type of the blob and is a required parameter by the Azure API
      def initialize(options = {})
        raise WAZ::Storage::InvalidOption, :name unless options.keys.include?(:name) and !options[:name].empty?
        raise WAZ::Storage::InvalidOption, :url unless options.keys.include?(:url) and !options[:url].empty?
        raise WAZ::Storage::InvalidOption, :content_type unless options.keys.include?(:content_type) and !options[:content_type].empty?
        self.name = options[:name]
        self.url = options[:url]
        self.content_type = options[:content_type]
      end
      
      # Returns the blob properties from Windows Azure. This properties always come as HTTP Headers and they include standard headers like
      # <em>Content-Type</em>, <em>Content-Length</em>, etc. combined with custom properties like with <em>x-ms-meta-Name</em>.
      def metadata
        self.class.service_instance.get_blob_properties(path)
      end
      
      # Returns the actual blob content, this method is specially used to avoid retrieving the whole blob
      # while iterating and retrieving the blob collection from the Container.
      def value
        @value ||= self.class.service_instance.get_blob(path)
      end
      
      # Assigns the given value to the blob content. It also stores a local copy of it in order to avoid round trips 
      # on scenarios when you do Save and Display on the same context.
      def value=(new_value)
        self.class.service_instance.put_blob(path, new_value, content_type, metadata)
        @value = new_value
      end

      # Stores the blob properties. Those properties are sent as HTTP Headers it's really important that you name your custom 
      # properties with the <em>x-ms-meta</em> prefix, if not the won't be persisted by the Windows Azure Blob Storage API.
      def put_properties!(properties = {})
        self.class.service_instance.set_blob_properties(path, properties)
      end
      
      # Removes the blob from the container.
      def destroy!
        self.class.service_instance.delete_blob(path)
      end
      
      # Returns the blob path. This is specially important when simulating containers inside containers
      # by enabling the API to point to the appropiated resource.
      def path
        url.gsub(/https?:\/\/[^\/]+\//i, '').scan(/([^&]+)/i).first().first()
      end
    end
  end
end
  
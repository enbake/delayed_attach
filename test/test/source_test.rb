require File.dirname(__FILE__) + '/test_helper.rb'

class SourceTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  include ActionView::Helpers::AssetTagHelper

  fixtures :attachments, :attachment_blobs

  def setup
    FileUtils.mkdir Attachment::FILE_STORE
    FileUtils.cp_r File.join(Fixtures::FILE_STORE, '.'), Attachment::FILE_STORE
  end

  def teardown
    FileUtils.rm_rf Attachment::FILE_STORE
  end

  def test_load_source_from_tempfile
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = Hapgood::Attach::Sources::Base.load(tf)
    assert_instance_of Hapgood::Attach::Sources::Tempfile, s
    assert s.valid?
    # Check data
    assert_kind_of ::ActionController::TestUploadedFile, s.tempfile
    assert_kind_of ::ActionController::TestUploadedFile, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_nil s.uri  # Tempfiles are not persistent
    assert_kind_of String, s.filename
    assert_kind_of Mime::Type, s.mime_type
    assert_kind_of String, s.digest
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(s.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
    assert_equal 4534, s.size
  end

  def test_load_source_from_file
    f = ::File.open(File.join(Attachment::FILE_STORE, 'SperrySlantStar.bmp'), "rb")
    s = Hapgood::Attach::Sources::Base.load(f)
    assert_instance_of Hapgood::Attach::Sources::File, s
    assert s.valid?
    # Check data
    assert_kind_of ::Tempfile, s.tempfile
    assert_kind_of ::IO, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_not_nil s.uri
    assert_equal "file://localhost#{f.path}", s.uri.to_s
    assert_equal 'SperrySlantStar.bmp', s.filename
    assert_equal 'image/bmp', s.mime_type.to_s # File's MIME type is guessed from extension
    assert_not_nil s.digest
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(s.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
    assert_equal 4534, s.size
  end

  def test_load_source_from_http
    uri = URI.parse("http://www.rubyonrails.org/images/rails.png")
    s = Hapgood::Attach::Sources::Base.load(uri)
    assert_instance_of Hapgood::Attach::Sources::Http, s
    assert s.valid?
    # Check data
    assert_kind_of ::Tempfile, s.tempfile
    assert_kind_of ::StringIO, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_not_nil s.uri
    assert_equal uri, s.uri
    assert_equal 'rails.png', s.filename
    assert_equal "image/png", s.mime_type.to_s
    assert_nil s.digest # This resource is not served with a rich HTTP header
    assert_equal 13036, s.size
  end

  def test_load_source_from_local_asset
    uri = URI.parse(image_path('logo.gif'))
    s = Hapgood::Attach::Sources::Base.load(uri)
    assert_instance_of Hapgood::Attach::Sources::LocalAsset, s
    assert s.valid?
    # Check data
    assert_kind_of ::Tempfile, s.tempfile
    assert_kind_of ::File, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_not_nil s.uri
    assert_equal uri, s.uri
    assert_equal 'logo.gif', s.filename
    assert_equal 'image/gif', s.mime_type.to_s # File's MIME type is guessed from extension
    assert_equal "Nlmsf6jL1y031dv5yaI3Ew==", Base64.encode64(s.digest).chomp! # This resource is not served with a rich HTTP header
    assert_equal 14762, s.size
  end

  def test_store_source_to_file
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = Hapgood::Attach::Sources::Base.load(tf)
    path = File.join(Attachment::FILE_STORE, 'uuid_aspect.extension')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = Hapgood::Attach::Sources::Base.store(s, uri)
    assert stat = File.stat(path)
    assert_equal 0644, stat.mode & 0777
    assert_equal 4534, File.size(path)
  end

  def test_store_source_to_file_with_relative_path
    begin
      tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
      s = Hapgood::Attach::Sources::Base.load(tf)
      path = File.join(File.join('test', 'public', 'attachments'), 'uuid_aspect.extension')
      uri = ::URI.parse(path)
      s = Hapgood::Attach::Sources::Base.store(s, uri)
      assert stat = File.stat(path)
      assert_equal 0644, stat.mode & 0777
      assert_equal 4534, File.size(path)
    ensure
      FileUtils.rm path
    end
  end

  def test_reload_source_from_file_uri
    path = File.join(Attachment::FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_reload_source_from_relative_uri
    path = File.join('..', 'public', 'attach_test', 'rails.png')
    uri = ::URI.parse(path)
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_reload_source_from_invalid_file_uri
    path = File.join(Attachment::FILE_STORE, 'xrails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    assert_raises Hapgood::Attach::MissingSource do
      s = Hapgood::Attach::Sources::Base.reload(uri)
    end
  end

  def test_reload_source_from_local_asset_uri
    uri = URI.parse(image_path('logo.gif'))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_kind_of Hapgood::Attach::Sources::LocalAsset, s
    assert_equal 14762, s.size
    assert_equal uri, s.uri
  end

  def test_destroy_file_backed_source
    path = File.join(Attachment::FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    s.destroy
    assert !File.readable?(path)
  end

  def test_destroy_local_asset_source
    path = File.join(Attachment::FILE_STORE, 'rails.png')
    uri = URI.parse(path)
    s = Hapgood::Attach::Sources::Base.reload(uri)
    s.destroy
    assert File.readable?(path)
  end

  def test_process_thumbnail_with_rmagick
    s = Hapgood::Attach::Sources::Base.load(fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
    assert s = Hapgood::Attach::Sources::Base.process(s, :thumbnail)
    assert_equal 128, s.metadata[:width]
    assert_equal 102, s.metadata[:height]
    assert_operator 4616..4636, :include?, s.size
    assert_operator 4616..4636, :include?, s.blob.size
  end

  def test_process_info_with_exifr
    s = Hapgood::Attach::Sources::Base.load(fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
    assert s = Hapgood::Attach::Sources::Base.process(s, :info)
    assert s.metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 28 Nov 1998 11:39:37 -0500'), s.metadata[:time].to_time
  end

  def test_process_with_icon
    s = Hapgood::Attach::Sources::Base.load(fixture_file_upload('attachments/empty.txt', 'text/plain', :binary))
    assert s = Hapgood::Attach::Sources::Base.process(s, :icon)
    assert_kind_of Hapgood::Attach::Sources::LocalAsset, s
    assert_equal 'image/png', s.mime_type.to_s
    assert_match /(\/.*)+\/mime_type_icons.text_plain\.png/, s.uri.path
  end
end
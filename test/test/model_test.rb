require File.dirname(__FILE__) + '/test_helper.rb'

class ModelTest < ActiveSupport::TestCase
  fixtures :users, :attachments, :attachment_blobs

  def test_create_attachment_via_file_with_no_aspects
    assert_difference 'Attachment.count' do
      a = Attachment.create(:attachee => users(:chris), :file => fixture_file_upload('binary/SperrySlantStar.bmp', 'image/bmp', :binary), :_aspects => [])
      assert a.valid?, a.errors.full_messages.first
      assert_not_nil a.filename
      assert_equal 'SperrySlantStar.bmp', a.filename
      assert_not_nil a.digest
      assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(a.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/binary/SperrySlantStar.bmp'))).chomp!
      assert_equal 4534, a.size
      assert_match %r(http:\/\/[\S]+\/media\/#{UUID_REGEXP}\/attachments\/#{UUID_REGEXP}.[\w]+), a.http_url
      assert a.aspects.empty?

      assert_not_nil a = Attachment.find(a.id)
      assert a.uri.absolute?
      assert_equal 'db', a.uri.scheme
      assert_equal a.id, a.uri.path.split('/')[-1]
    end
  end

  def test_create_attachment_via_url_with_no_aspects
    url = "http://cho.hapgoods.com/wordpress"
    assert_difference 'Attachment.count' do
      a = Attachment.create(:attachee => users(:chris), :url => url, :_aspects => [])
      assert a.valid?, a.errors.full_messages.first
      assert_equal url, a.url
      assert a.aspects.empty?
    end
  end

  def test_create_system_attachment_via_file_with_default_aspect
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:attachee => users(:chris), :file => fixture_file_upload('binary/SperrySlantStar.bmp', 'image/bmp', :binary), :system => true)
      assert a.valid?, a.errors.full_messages.first
      assert users(:chris).attachments.first.valid?
      assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(a.digest).chomp!  # Digest::MD5.digest(File.read('test/fixtures/binary/SperrySlantStar.bmp'))
      assert_equal 4534, a.size
      assert_match %r(http:\/\/[\S]+\/media\/#{UUID_REGEXP}\/attachments\/#{UUID_REGEXP}.[\w]+), a.http_url
    end
  end

  def test_create_attachment_via_file_with_explicit_aspects
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:attachee => users(:chris), :file => fixture_file_upload('binary/AlexOnBMW#4.jpg', 'image/jpeg', :binary), :_aspects => [:thumbnail])
      assert a.valid?, a.errors.full_messages.first
      assert_equal 'NxzAvUsuKjk8tPhbnbgLjQ==', Base64.encode64(a.digest).chomp! # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/binary/AlexOnBMW#4.jpg')))
      assert_equal "320x256", a.image_size
      assert_equal 25535, a.blob.size
      assert_equal 25535, a.size
      assert_equal 320, a.metadata[:width]
      assert_equal 256, a.metadata[:height]
      assert_match %r(http:\/\/[\S]+\/media\/#{UUID_REGEXP}\/attachments\/#{UUID_REGEXP}.[\w]+), a.http_url
      assert_match %r(db:\/\/[\S]+\/#{UUID_REGEXP}), a.uri.to_s
      assert a.metadata.any?
      assert a.metadata.has_key?(:time)
      assert a.metadata[:time].acts_like?(:time)
      aspect = a.aspects.find_by_aspect('thumbnail')
      assert_equal 128, aspect.metadata[:width]
      assert_equal 102, aspect.metadata[:height]
      assert_operator 4616..4636, :include?, aspect.size
      assert_operator 4616..4636, :include?, aspect.blob.size
      assert aspect.attachee
      assert_equal users(:chris), aspect.attachee
    end
  end

  def test_create_attachment_via_url_with_default_aspects
    assert_difference 'Attachment.count', 2 do
      url = 'http://www.memoryminer.com/graphics/missingphoto.jpg'
      a = Attachment.create(:attachee => users(:chris), :url => url)
      assert a.valid?, a.errors.full_messages.first
      assert_not_nil a.filename
      assert_equal "missingphoto.jpg", a.filename
      assert_equal url, a.url
      assert_not_nil a.metadata
      assert_equal "800x600", a.image_size
      assert a.aspects.any?
      aspect = a.aspects.find_by_aspect('thumbnail')
      assert_equal "128x96", aspect.image_size
      assert_equal "image/jpeg", aspect.content_type
      # TODO: Validate this aspect further.
    end
  end

  def test_create_attachment_via_url_with_aspect_url
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:attachee => users(:chris), :url => 'http://cho.hapgoods.com/icons/powered_by_fedora.png', :_aspects => {:thumbnail => {:url => 'http://cho.hapgoods.com/icons/apache_pb2.gif'}})
      assert a.valid?, a.errors.full_messages.first
      assert a.aspects.any?
      assert a.size
      aspect = a.aspects.find_by_aspect('thumbnail')
      assert_not_nil a.size
    end
  end

  def test_create_attachment_via_url_with_aspect_file
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:attachee => users(:chris), :url => 'http://cho.hapgoods.com/wordpress/', :_aspects => {:thumbnail => {:file => fixture_file_upload('binary/SperrySlantStar.bmp', 'image/bmp', :binary)}})
      assert a.valid?, a.errors.full_messages.first
      assert a.aspects.any?
    end
  end
  
  # Classic problems here include caching sources in a limited high-performance mode during validation only to find that all data is required later.
  # Also state variables (store, _aspects) in the attach instnace methods are tricky to keep in sync during assignment.
  def test_validation_independence
    assert_nothing_raised do
      a = Attachment.new(:attachee => users(:chris), :file => fixture_file_upload('/attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
      assert a.valid?
      a.save!
    end
  end

  def test_create_attachment_with_malformed_url
    assert_raises URI::InvalidURIError do
      a = Attachment.create(:attachee => users(:chris), :url => "http://")
    end
  end

  # Should only create one attachment as the URL could not be retrieved and thus the default aspects are not built.
  def test_create_attachment_with_preloaded_data
    assert_difference 'Attachment.count', 1 do
      a = Attachment.create(:attachee => users(:chris), :uri => "http:/www.memoryminer.com/bogusresource.jpg", :size => 10240, :content_type => 'image/jpg', :_aspects => [])
    end
  end

  # Both the aspect and the primary URL are not (yet) valid, but valid metadata is present.
  def test_create_attachment_with_preloaded_data_and_aspect
    assert_difference 'Attachment.count', 2 do
      tparms = {:thumbnail => {:uri => "http://www.memoryminer.com/bogusresource-t.jpg", :size => 1024, :content_type => 'image/jpg'}}
      aparms = {:attachee => users(:chris), :uri => "http://www.memoryminer.com/bogusresource.jpg", :size => 10240, :content_type => 'image/jpg', :_aspects => tparms}
      a = Attachment.create(aparms)
    end
  end

  def test_source_required_on_save
    assert_no_difference 'Attachment.count' do
      a = Attachment.new({:attachee => users(:chris)})
      a.save
      assert a.errors.any?
    end
  end
  
  def test_single_source_required
    assert_no_difference 'Attachment.count' do
      assert_raise RuntimeError do
        a = Attachment.new({:attachee => users(:chris), :url => 'http://www.memoryminer.com/', :file => fixture_file_upload('binary/SperrySlantStar.bmp', 'image/bmp', :binary)})
        a.save
      end
    end
  end
  
  def test_delete_simple
    assert_difference 'Attachment.count', -1 do
      assert_difference AttachmentBlob, :count, -1 do #DbFile.count
        res = attachments(:sss).destroy
      end
    end
  end
  
  def test_delete_with_aspects
    res = attachments(:one)
    assert 1, res.aspects.size
    assert_difference 'Attachment.count', -2 do # Deletes child aspect as well.
      assert_difference AttachmentBlob, :count, -2 do #DbFile.count
        res.destroy
      end
    end
  end
  
  def test_update_simple
    a = Attachment.find(attachments(:two).id)
    a.description = "Updated Description"
    assert_nothing_raised do 
      a.save!
    end
    assert_equal "Updated Description", Attachment.find(attachments(:two).id).description
  end
  
  def test_create_simple
    assert_no_difference Attachment, :count do
      assert_nothing_raised do
        a = Attachment.create
      end
    end
  end
  
  def test_info
    assert attachments(:second).metadata[:time]
    assert attachments(:second).metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 28 Nov 1998 11:39:37 +0000'), attachments(:second).metadata[:time]
  end

  def test_info_on_new
    a = Attachment.create(:attachee => users(:chris), :file => fixture_file_upload('binary/AlexOnBMW#4.jpg', 'image/jpeg', :binary), :_aspects => {})
    assert a.metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 28 Nov 1998 11:39:37 +0000'), a.metadata[:time].to_time
  end
  
  def test_update
    url = "http://www.rubyonrails.org/images/rails.png"
    attachments(:sss).update_attributes({:url => url})
    assert_equal url, attachments(:sss).url
  end
  
  def test_create_aspect_post_facto
    assert_difference 'Attachment.count' do
      Attachment.create(:attachee => users(:pascale), :file => fixture_file_upload('binary/SperrySlantStar.bmp', 'image/bmp', :binary), :parent_id => attachments(:sss).id, :aspect => '*proof')
    end
    assert_equal 1, attachments(:sss).aspects.size
    assert a = attachments(:sss).aspects.first
    assert_equal "*proof", a.aspect
    assert a.system, "Aspect of a system attachment should also be a system attachment."
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(a.digest).chomp!  # Digest::MD5.digest(File.read('test/fixtures/binary/SperrySlantStar.bmp'))
    assert_equal 4534, a.size
    assert_match %r(http:\/\/[\S]+\/media\/#{UUID_REGEXP}\/attachments\/#{UUID_REGEXP}.[\w]+), a.http_url
  end
end
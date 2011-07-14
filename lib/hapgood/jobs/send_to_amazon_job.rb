class SendToAmazonJob
  @queue = "AmazonTransfers"

  # perform the transfer to Amazon.
  def self.perform(id, s3_bucket, aspects)
    attachment = Attachment.find(id)
    options = {:store => Proc.new {|i, e| "s3://s3.amazonaws.com/#{::File.join(s3_bucket, i.to_s[0,1], [i, e].compact.join('.'))}"}, :aspect => aspects}
    attachment.perform_remote_transfer(options)
    attachment.save(false)
  end
end
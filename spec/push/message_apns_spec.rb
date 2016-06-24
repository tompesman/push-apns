require 'spec_helper'

describe Push::MessageApns do
  let(:app) { 'com.test.app' }
  let(:device) { 'ce8be6272e43e85516033e24b4c289220eeda4879c477160b2545e95b68b5969' }
  let(:expiry) { 1.day.to_i }
  let(:badge) { 1 }
  let(:attributes_for_device) {
    {
      test: 1
    }
  }
  let(:sound) { 'default' }
  let(:alert) { 'We have a new push notification for you' }
  let(:content_available) { 1 }
  let(:priority) { 10 }
  let(:notification_options) {
    {
      app: app,
      device: device,
      expiry: expiry,
      badge: badge,
      attributes_for_device: attributes_for_device,
      sound: sound,
      alert: alert,
      content_available: content_available,
      priority: priority
    }
  }
  let(:instance) { Push::MessageApns.create(notification_options) }

  describe "#badge" do
    subject { instance.badge }
    it { should == badge }
  end

  describe "#alert" do
    subject { instance.alert }
    it { should == alert }
  end

  describe "#app" do
    subject { instance.app }
    it { should == app }
  end

  describe "#sound" do
    subject { instance.sound }
    it { should == sound }
  end

  describe "#expiry" do
    subject { instance.expiry }
    it { should == expiry }
  end

  describe "#device" do
    subject { instance.device }
    it { should == device }
  end

  describe "#content_available" do
    subject { instance.content_available }
    it { should == content_available }
  end

  describe "#priority" do
    subject { instance.priority }
    it { should == priority }
  end

  describe "#attributes_for_device" do
    subject { instance.attributes_for_device }
    it { should == { "test" => 1 } }
  end

  describe "#payload" do
    it "should create compliant json structure" do
      expect(instance.payload).to eq(MultiJson.dump({
        "aps" => {
          "alert" => alert,
          "badge" => badge,
          "sound" => sound,
          "content-available" => content_available
        },
        "test" => "1"
      }))
    end
  end

  describe "#to_message" do
   it "should create a message with command 2" do
     command, _1, _2 = instance.to_message.unpack("cNa*")
     expect(command).to eq(2)
   end

   it "should create a message with correct frame length" do
     _1, length, _2 = instance.to_message.unpack("cNa*")
     expect(length).to eq(176)
   end

   def items
     _1, _2, items_stream = instance.to_message.unpack("cNa*")
     items = []
     until items_stream.empty?
       item_id, item_length, items_stream = items_stream.unpack("cna*")
       item_data, items_stream = items_stream.unpack("a#{item_length}a*")
       items << [item_id, item_length, item_data]
     end
     items
   end

   it "should include five items" do
     expect(items.size).to eq(5)
   end

   it "should include item #1 with the token as hexadecimal" do
     expect(items).to include([1, 32, [device].pack("H*")])
   end

   it "should include item #2 with the payload as JSON" do
     expect(items).to include([2, 120, "{\"aps\":{\"alert\":\"We have a new push notification for you\",\"badge\":1,\"sound\":\"default\",\"content-available\":1},\"test\":\"1\"}"])
   end

   it "should include item #3 with the identifier" do
     expect(items).to include([3, 4, [1].pack("N")])
   end

   it "should include item #4 with the expiry" do
     expect(items).to include([4, 4, [expiry].pack("N")])
   end

   it "should include item #5 with the priority" do
     expect(items).to include([5, 1, [priority].pack("c")])
   end
  end
end

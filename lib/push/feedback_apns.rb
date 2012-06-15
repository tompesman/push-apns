module Push
  class FeedbackApns < Push::Feedback
    validates :device, :format => { :with => /\A[a-z0-9]{64}\z/ }
  end
end
module Push
  class FeedbackApns < Push::Feedback
    attr_accessible :device, :follow_up, :failed_at
    validates :device, :format => { :with => /\A[a-z0-9]{64}\z/ }
    validates :follow_up, :inclusion => { :in => %w(delete), :message => "%{value} is not a valid follow-up" }
  end
end
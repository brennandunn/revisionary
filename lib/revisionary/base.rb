module Revisionary
  
  module ClassMethods
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
  end
end
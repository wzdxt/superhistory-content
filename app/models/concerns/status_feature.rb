module StatusFeature
  def self.included(base)
    base::STATUS.constants.reject { |s| s.is_a? Array }.each do |attr|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{attr}?
          self.status == self.class::STATUS::#{attr}
        end
      METHOD
    end
  end
end

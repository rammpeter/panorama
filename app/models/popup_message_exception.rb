class PopupMessageException < Exception
  def initialize(message, org_exception = nil)
    super(message)
    @org_exception = org_exception
  end

  def org_exception
    @org_exception
  end
end
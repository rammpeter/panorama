class Container
    
  def initialize( entries = {} )
    @entries = {}
    entries.each do |k,v|
      set_property( k.to_s, v )
    end
  end
  
  def respond_to?(symbol,include_private = false)
  
  end
  
  def method_missing( method_id, *args)

    if args.empty? # getter      
      return get_property( method_id.to_s )

    else # setter
      methodname = method_id.to_s
      methodname = methodname[0, methodname.length-1 ]
      set_property( methodname, args[0] ) 
      return
    end
    
  end

  def []( name, value )    
    set_property(name.to_s, value)
  end

  def []( name )
    get_property(name.to_s)
  end
    
  private  
  
  def get_property( name )
    @entries[ name.downcase.to_sym ]       
  end
  
  def set_property( name, value )
    @entries[ name.downcase.to_sym ] = value 
  end
  
end

c = Container.new( { :ID_CusTOMER => 12 } )
c.ID_CUSTOMER = 13

# encoding: utf-8
require "date"
require "base64"
class OnlineQueueController < ApplicationController
  
  def start_working
    @message_types = Ofmessagetype.find_by_sql('SELECT * FROM sysp.OFMessageType')
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "online_queue/start_working" }');"}
    end
  end

  def get_gaattr_colour_by_id( id )        
    
    if id == 6216
      '0x000000'
    elsif id == 6217
      '0x000066'
    elsif id == 6218
      '0x00CC99'
    elsif id == 6279
      '0x33FF33'
    elsif id == 6280
      '0x9977CC'
    elsif id == 6281
      '0x990099'
    elsif id == 6282      
      '0xFF0033'
    elsif id == 6283      
      '0xFF3366'
    elsif id == 6284            
      '0x9953CC'
    end
        
  end

  
  def show_chart
      
    h = {}
    
    if params[:post][:select_criterion] == 'minutes'
      action = "get_for_last_minutes"
      h[ :t ] = params[:post][:minutes]
    else
      action = "get_for_rage"      
      h[ :f ] = "#{params[:post][:from_date]} #{params[:post][:from_time]}"
      h[ :t ] = "#{params[:post][:to_date]} #{params[:post][:to_time]}"
    end
      
    a = []
    h[ :a ] = a
    params[:post].each do |k,v|
      
      if k[0,7] == 'aspect_'        
        a << "#{k[7,k.length]}".to_i
      end
    end       
    
    if params[:post][:message_type] != 'Alle'
      h[ :m ] = get_message_type_id_by_name( params[:post][:message_type] )
    end
    
    h[ :s ] = params[:post][:sum_minutes]
    
    string = Base64.encode64( Marshal.dump(h) ).strip
    
    @graph = open_flash_chart_object(700,400, "/online_queue/#{action}/#{string}", false, '/')
    respond_to do |format|
      format.js {render :js => "$('#chart').html('#{j render_to_string :partial=>"show_chart" }');"}
    end

  end
  
  def get_for_last_minutes
    h            = Marshal.load(Base64.decode64( params[:id] ))    
    minutes      = h[:t]
    message_type = h[:m]
    aspects      = h[:a]
    sum_minutes  = h[:s]
    g            = load( minutes.to_i.minutes.ago, DateTime.now, message_type, aspects, sum_minutes )
    render :text => g.render
  end
  
  def get_for_rage  
    h            = Marshal.load(Base64.decode64( params[:id] ))    
    from         = DateTime.strptime( h[:f], "%d.%m.%Y %H:%M" )
    to           = DateTime.strptime( h[:t], "%d.%m.%Y %H:%M" )
    message_type = h[:m]
    aspects      = h[:a]    
    sum_minutes  = h[:s]
    g            = load( from, to, message_type, aspects, sum_minutes )
    render :text => g.render    
  end
  
 
  
  def load( from, to, message_type, aspects, sum_minutes )
  
    sum_minutes = sum_minutes.to_i
    #puts "from #{from} to #{to} message_type #{message_type} aspects #{aspects}"
    from_min = to_minutes( from )
    to_min   = to_minutes( to )
    
    
    query = "SELECT " +
            "  MINUTE - MOD(MINUTE, #{sum_minutes}), " +
            "  SUM(DECODE(ID_GAAttr,6216, Counter, 0)) FirstTrySuccess, " +      
            "  SUM(DECODE(ID_GAAttr,6217, Counter, 0)) RetrySuccess, " +        
            "  SUM(DECODE(ID_GAAttr,6218, Counter, 0)) FinalError, " +           
            "  SUM(DECODE(ID_GAAttr,6279, Counter, 0)) DivideAndConquer, " +    
            "  SUM(DECODE(ID_GAAttr,6280, Counter, 0)) RetryTx, " +              
            "  SUM(DECODE(ID_GAAttr,6281, Counter, 0)) FirstTry, " +            
            "  SUM(DECODE(ID_GAAttr,6282, Counter, 0)) Retries, " +              
            "  SUM(DECODE(ID_GAAttr,6283, Counter, 0)) FirstTryError, " +        
            "  SUM(DECODE(ID_GAAttr,6284, Counter, 0)) RetryError " +            
            "FROM " + 
            "  sysp.onlineaspect " +
            "WHERE " +
            "    ID_APPLICATION = 1343 " +
            "AND MINUTE >= #{from_min} " +
            "AND MINUTE <= #{to_min} "

            if message_type
              query += "AND SUBKEY = #{message_type} "
            end
            
            query += "GROUP BY "
            query += "MINUTE - MOD (MINUTE, #{sum_minutes})"
        
    cursor = create_cursor( query )
    
    cursor.exec
    
    last_min = from_min
    
    max_y = 0
    
    result = {};
    
    while r = cursor.fetch()
      
      while ( last_min + sum_minutes ) < r[0] 
        append_null( result, aspects )  
        last_min += sum_minutes
      end

      last_min = r[0]
      m = append( result, aspects, r )
      
      max_y = m if m > max_y      
      
    end
    
    while last_min < to_min
        append_null( result, aspects )  
        last_min += sum_minutes    
    end

    g = Graph.new
    g.title( "Aspects", '{font-size: 26px;}')

    result.each do |k,v|
      g.set_data( v )        
      g.line_hollow( 1, 4, get_gaattr_colour_by_id( k ), nil, 10 )
    end

    g.set_y_max( max_y )    
    g.set_y_label_steps(5)

    return g
  end
  
  def append_null( result, aspects )
    
      for a in aspects
        l = result[ a ] ||= []  
        l << 0 
      end

  end
    
    
  def append( result, aspects, attribues )
      
      max = 0
      
      for a in aspects
        l = result[ a ] ||= []  
        
        if a == 6216
          l << attribues[ 1 ]
        elsif a == 6217
          l << attribues[ 2 ]
        elsif a == 6218
          l << attribues[ 3 ]
        elsif a == 6279
          l << attribues[ 4 ]
        elsif a == 6280
          l << attribues[ 5 ]
        elsif a == 6281
          l << attribues[ 6 ]
        elsif a == 6282      
          l << attribues[ 7 ]
        elsif a == 6283      
          l << attribues[ 8 ]
        elsif a == 6284            
          l << attribues[ 9 ]
        else
          puts 'scheiße ' + a
        end
         #puts l
        max = l[ l.length-1 ] if max < l[ l.length-1 ]                
    end
    
    max
  end
  
  def to_minutes( date )
      s = date.strftime( "%d.%m.%Y %H:%M" )
      sql_select_all( ["SELECT (TO_CHAR( to_date( ?, '#{sql_datetime_minute_mask}' ) ,'J') * 24 + TO_CHAR( to_date( ?, '#{sql_datetime_minute_mask}' ), 'HH24')) * 60 + TO_CHAR( to_date( ?, '#{sql_datetime_minute_mask}' ), 'MI') Minute FROM DUAL", s, s, s ] )[0].minute
  end
  

  
  def get_message_type_id_by_name( name )
    Ofmessagetype.find_by_name( name ).id
  end
  
  def one
    g = Graph.new
    g.title("Spoon Sales", '{font-size: 26px;}')
    g.set_data( [0,0,33,16,7,9,30,48,63,49,16,49] )        
    #   g.set_data( [0,0,33,16,7,9] )        
    #    g.line(10, '0x9933CC', 'Hallo')
    g.line_hollow(1, 4, '0x9933CC', 'Hallo', 10 )
    
    #    g.set_x_labels(%w(Jan,,,,,,,,,,Dec))
    g.set_y_max(50)
    g.set_y_label_steps(5)
    render :text => g.render
        
  end  
  
end
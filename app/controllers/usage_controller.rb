# encoding: utf-8
class UsageController < ApplicationController
  def info
   session[:database] = Database.new unless session[:database]
    fill_usage_info
  end

  def fill_usage_info
    file = File.open(Panorama::Application.config.usage_info_filename, "r")
    months = {}
    begin
      while true do
        recs = file.readline.split    # Einzelne Felder in Array
        ip         = recs[0]
        db         = recs[1]
        month      = recs[2]
        controller = recs[3]
        action     = recs[4]

        if months[month]
          months[month][:Requests] = months[month][:Requests] +1
          months[month][:Databases][db]           = months[month][:Databases][db]           ? months[month][:Databases][db] +1           : 1
          months[month][:Clients][ip]             = months[month][:Clients][ip]             ? months[month][:Clients][ip] +1             : 1
          months[month][:Controllers][controller] = months[month][:Controllers][controller] ? months[month][:Controllers][controller] +1 : 1
          months[month][:Actions][action]         = months[month][:Actions][action]         ? months[month][:Actions][action] +1         : 1
        else
          months[month] = {:Requests     => 1,
                           :Databases    => { db         => 1},
                           :Clients      => { ip         => 1},
                           :Controllers  => { controller => 1},
                           :Actions      => { action     => 1},
          }
        end
      end
    rescue EOFError
      file.close
    end

    @usage = []
    months.each do |key,value|
      value[:Month]       = key
      value[:Databases]   = value[:Databases].count
      value[:Clients]     = value[:Clients].count
      value[:Controllers] = value[:Controllers].count
      value[:Actions]     = value[:Actions].count
      value.extend SelectHashHelper
      @usage << value
    end

  end

  def detail_sum
    @groupkey = params[:groupkey]
    @filter   = params[:filter]

    file = File.open(Panorama::Application.config.usage_info_filename, "r")
    groups = {}
    begin
      while true do
        recs = file.readline.split    # Einzelne Felder in Array
        ip         = recs[0]
        db         = recs[1]
        month      = recs[2]
        controller = recs[3]
        action     = recs[4]
        rec = {:Database   => db,
               :IP_Address => ip,
               :Month      => month,
               :Controller => controller,
               :Action     => action
        }

        groupvalue = rec[@groupkey.to_sym]                     # Konkreter Wert des Gruppierungs-Feldes für diesen Record
        filtered = true
        @filter.each do |key, value|                    # Iteration ueber alle zu filternden Felder
          filtered = false if rec[key.to_sym] != value     # Ausfiltern wenn Filterattribut != Wert in aktueller Zeile
        end

        if filtered
          if groups[groupvalue]
            groups[groupvalue][:Requests] = groups[groupvalue][:Requests] +1
            groups[groupvalue][:Databases][db]           = groups[groupvalue][:Databases][db]           ? groups[groupvalue][:Databases][db] +1           : 1
            groups[groupvalue][:Clients][ip]             = groups[groupvalue][:Clients][ip]             ? groups[groupvalue][:Clients][ip] +1             : 1
            groups[groupvalue][:Controllers][controller] = groups[groupvalue][:Controllers][controller] ? groups[groupvalue][:Controllers][controller] +1 : 1
            groups[groupvalue][:Actions][action]         = groups[groupvalue][:Actions][action]         ? groups[groupvalue][:Actions][action] +1         : 1
          else
            groups[groupvalue] = {:Requests     => 1,
                                  :Databases    => { db         => 1},
                                  :Clients      => { ip         => 1},
                                  :Controllers  => { controller => 1},
                                  :Actions      => { action     => 1},
            }
          end
        end
      end
    rescue EOFError
      file.close
    end

    @usage = []
    groups.each do |key,value|
      value[:Groupkey]    = key
      value[:Databases]   = value[:Databases].count
      value[:Clients]     = value[:Clients].count
      value[:Controllers] = value[:Controllers].count
      value[:Actions]     = value[:Actions].count
      value.extend SelectHashHelper
      @usage << value
    end

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"detail_sum" }');"}
    end
  end

  def single_record
    @filter   = params[:filter]
    file = File.open(Panorama::Application.config.usage_info_filename, "r")
    @recs = []
    begin
      while true do
        recs = file.readline.split    # Einzelne Felder in Array
        ip         = recs[0]
        db         = recs[1]
        month      = recs[2]
        controller = recs[3]
        action     = recs[4]
        ts         = recs[5]
        rec = {:Database   => db,
               :IP_Address => ip,
               :Month      => month,
               :Controller => controller,
               :Action     => action,
               :Timestamp  => ts
        }

        filtered = true
        @filter.each do |key, value|                    # Iteration ueber alle zu filternden Felder
          filtered = false if rec[key.to_sym] != value     # Ausfiltern wenn Filterattribut != Wert in aktueller Zeile
        end

        if filtered
          rec.extend SelectHashHelper
          @recs << rec
        end
      end
    rescue EOFError
      file.close
    end
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"single_record" }');"}
    end
  end

  def ip_info
    ip_address = params[:ip_address]

    output = "<h3>Info zu IP-Adresse #{ip_address}</h3>
<h4>nslookup:</h4>
#{my_html_escape `nslookup #{ip_address} `}
<h4>nmblookup -A:</h4>
#{my_html_escape `nmblookup -A #{ip_address} `}
"

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j output}');"}
    end
  end

end

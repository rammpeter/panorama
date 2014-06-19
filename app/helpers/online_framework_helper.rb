# encoding: utf-8
module OnlineFrameworkHelper

  def msgType(id_ofmessagetype)
    Ofmessagetype.get_cached_instance(id_ofmessagetype, session[:database].hash)
  end

  # Anlage der Spalten, die in jeder Ansicht der Historie zu sehen sind
  def define_default_columns

    def elapsed(rec)
      ((rec.firsttry.to_i+rec.retries.to_i) == 0) ? "?" : formattedNumber(rec.elapsedmilliseconds.to_i/(rec.firsttry.to_i+rec.retries.to_i), 2)
    end

    def msg_per_bulkgroup(rec)
      (rec.bulkgroups == 0) ? "?" : formattedNumber((rec.firsttry+rec.retries).to_f / rec.bulkgroups, 2)
    end

    def elapsed_per_bulkgroup(rec)
      (rec.bulkgroups.to_i == 0) ? "?" : formattedNumber(rec.elapsedmilliseconds.to_i/1000.0/rec.bulkgroups.to_i, 2)
    end

    def SLA_title_warning(rec)
      if rec['id_ofmessagetype']
        if msgType(rec.id_ofmessagetype).waitlimitwarning
          "Limit für Warnung = #{msgType(rec.id_ofmessagetype).waitlimitwarning} Minuten"
        else
          'Kein Limit für Warnung definiert für diesen Messagetyp'
        end
      end
    end

    def SLA_title_alert(rec)
      if rec['id_ofmessagetype']
        if msgType(rec.id_ofmessagetype).waitlimitalert
          "Limit für Alert = #{msgType(rec.id_ofmessagetype).waitlimitalert} Minuten"
        else
          'Kein Limit für Alert definiert für diesen Messagetyp'
        end
      end
    end

    [
        {:caption=>"Incoming",          :data=>proc{|rec| formattedNumber(rec.incoming)},                         :title=>"Anzahl der eingehenden Messages",     :align=>'right'},
        {:caption=>"First Try Success", :data=>proc{|rec| formattedNumber(rec.firsttrysuccess)},                  :title=>"Anzahl der beim ersten Versuch erfolgreich verarbeiteten Messages",     :align=>'right'},
        {:caption=>"Retry Success",     :data=>proc{|rec| formattedNumber(rec.retrysuccess)},                     :title=>"Anzahl der nach Wiederholung erfolgreich verarbeiteten Messages",     :align=>'right'},
        {:caption=>"Final Errors",      :data=>proc{|rec| link_errors(rec, formattedNumber(rec.finalerror))},     :title=>"Anzahl der nach x Wiederholungen als fehlerhaft markierten Messages",     :align=>'right'},
        {:caption=>"Divide and Conquer",:data=>proc{|rec| formattedNumber(rec.divideandconquer)},                 :title=>"Anzahl der Divide&Conquer-Vorgänge nach Persist-Fehlern",     :align=>'right'},
        {:caption=>"Compressions",      :data=>proc{|rec| formattedNumber(rec.compressions)},                     :title=>"Anzahl der bei Verdichtung nach BulkCriteria gelöschten Messages (Wenn OFMessageType.YN_ProcessUniqueOnlyOnce=Y)",     :align=>'right'},
        {:caption=>"Retry Transaction", :data=>proc{|rec| formattedNumber(rec.retrytx)},                          :title=>"Anzahl Neustart der Verarbeitung von Tx-Gruppen nach Aussteuern fehlerhafter Messages bei handleMessage",     :align=>'right'},
        {:caption=>"First Try",         :data=>proc{|rec| formattedNumber(rec.firsttry)},                         :title=>"Anzahl der erstmaligen Berarbeitungsversuche von Messages",     :align=>'right'},
        {:caption=>"Retry",             :data=>proc{|rec| formattedNumber(rec.retries)},                          :title=>"Anzahl der wiederholten Berarbeitungsversuche von Messages",     :align=>'right'},
        {:caption=>"First Try Error",   :data=>proc{|rec| link_errors(rec, formattedNumber(rec.firsttryerror))},  :title=>"Anzahl der nach erstem Verarbeitungsversuch wegen Fehler in Queue zurückgestellten Messages",     :align=>'right'},
        {:caption=>"Retry Error",       :data=>proc{|rec| link_errors(rec, formattedNumber(rec.retryerror))},     :title=>"Anzahl der nach wiederholtem Verarbeitungsversuch wegen Fehler in Queue zurückgestellten Messages",     :align=>'right'},
        {:caption=>"Elapsed total",     :data=>proc{|rec| formattedNumber(rec.elapsedmilliseconds.to_i/1000)},    :title=>"Verarbeitungszeit total im Betrachtungszeitraum in Sekunden",     :align=>'right'},
        {:caption=>"Elapsed / Msg",     :data=>proc{|rec| elapsed(rec)},                                          :title=>"Verarbeitungszeit je Message in Millisekunden",     :align=>'right'},
        {:caption=>"Bulk-Groups",       :data=>proc{|rec| formattedNumber(rec.bulkgroups)},                       :title=>"Anzahl durch Worker verarbeitete Bulk-Groups",     :align=>'right'},
        {:caption=>"Msg. / Bulkgroup",  :data=>proc{|rec| msg_per_bulkgroup(rec)},                                :title=>"Durchschn. Anzahl Messages je Bulkgroup",     :align=>'right'},
        {:caption=>"Elapsed / Bulkgroup",:data=>proc{|rec| elapsed_per_bulkgroup(rec)},                           :title=>"Verarbeitungszeit je Bulkgroup in Sekunden",     :align=>'right'},
        {:caption=>"SLA Warnings",      :data=>proc{|rec| fn(rec.sla_warnings)},                                  :title=>"Anzahl Warnungen wegen Überschreiten der SLA-Zeiten zwischen Einstellen und Verarbeitung von Messages", :data_title=>proc{|rec| "%t: #{SLA_title_warning(rec)}"},  :align=>'right'},
        {:caption=>"SLA Alerts",        :data=>proc{|rec| fn(rec.sla_alerts)},                                    :title=>"Anzahl Alerts wegen Überschreiten der SLA-Zeiten zwischen Einstellen und Verarbeitung von Messages",    :data_title=>proc{|rec| "%t: #{SLA_title_alert(rec)}"},    :align=>'right'},
    ]
  end


end

// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

// Eigenes jQuery verwenden, da Version aus jquery_rails $.browser nicht unterstützte
//= require jquery-1.10.2
//= require jquery-ui-1.10.3.custom
//= require jquery_ujs
//= require jquery-ui-timepicker-addon
//= require jquery_table2CSV
//= require flot/jquery.flot
//= require flot/jquery.flot.resize
//= require flot/jquery.flot.crosshair
//= require context/jquery.contextmenu.js
//= require jquery.event.drag-2.2
//= require slick.core
//= require slick.grid
//= require slick.dataview
//= require jqgrid/jquery.contextmenu.js
//= require superfish/hoverIntent
//= require superfish/superfish
//= require_tree .

// global gültige Variable im js, wird von EnvController.setDatabase gesetzt entsprechend der Spracheinstellung
var session_locale = "en";
var numeric_decimal_separator = '.';
var show_trace_output = false;                                                  // Anzeige Trace-Output in Konsole
var one_time_suppress_indicator = false;                                        // Unterdrückend er Anzeige des Indicators für einen Aufruf

function showIndicator() {
    if (!one_time_suppress_indicator)                                           // Einmaliges Unterdrücken der Anzeige Indikator
        jQuery("#ajax_indicator").dialog("open");
    else
        one_time_suppress_indicator = false;                                    // Zurücksetzen auf Default
}

function hideIndicator() {
    jQuery("#ajax_indicator").dialog("close");
}

var tooltip_document_body = null;
function closeAllTooltips(self_tooltip){
    if (tooltip_document_body == null)
        tooltip_document_body = jQuery(document.body);
    tooltip_document_body.children(".ui-tooltip").each(function(i){
        if (!self_tooltip || jQuery(this).attr('id') != self_tooltip.attr('id'))
        jQuery(this).remove();
    });

}

// jQuery.UI Tooltip verwenden
function register_tooltip(jquery_object){
    jquery_object.tooltip({                                              // ui-tooltips verwenden
        tooltipClass: 'tooltip_class',
        open: function(event, ui){
            closeAllTooltips(ui.tooltip);
        },
        show: {
            effect: "slideDown",
            duration: "fast",
            delay: 1000
        },
        hide: {
            effect: "slideUp"
        }
    }).off('focusin');
}



// DOM-Tree auf doppelte ID's testen
function check_dom_for_duplicate_ids() {
    var idDictionary = {};
    jQuery('[id]').each(function(index, element) {
        idDictionary[this.id] == undefined ? idDictionary[this.id] = 1 : idDictionary[this.id] ++;
    });
    for (id in idDictionary) {
        if (idDictionary[id] > 1) {
            console.warn("Duplicate html-IDs in Dom-Tree:\nID " + id + " was used " + (idDictionary[id]) + " times: "+jQuery('#'+id).html());
            console.log("====================================================================================");
            jQuery('#'+id).each(function(index, element) {
                console.log(jQuery(element).html());
                console.log(jQuery(element).parent().attr("id") + " "+jQuery(element).parent().attr("class"));
            });
            console.log("====================================================================================");
        }
    }
}



var SQL_shortText_Cache = {};                                                   // Cache für SQL-IDs


// Erweitern des Hints für SQL-ID um SQL-Text
function expand_sql_id_hint(id, sql_id){
    function get_content(id, short_text){
        return $('#'+id).attr('prefix')+"\n"+short_text;
    }

    // Title setzen mit Text
    function set_sql_title(id, short_text){
        jQuery('#'+id).attr('title', get_content(id, short_text));
    }

    if (SQL_shortText_Cache[sql_id]){
        set_sql_title(id, SQL_shortText_Cache[sql_id]);
    }
    else {
        SQL_shortText_Cache[sql_id] = "< SQL-Text: request in progress>"        // Verhindern, dass während der Abfrage erneut nachgefragt wird
        jQuery.ajax({url: "DbaHistory/getSQL_ShortText?sql_id="+sql_id,
            dataType: "json",
            beforeSend: function(response) {
                one_time_suppress_indicator = true;                             // Unterdrückend der Anzeige des Indicators für einen Aufruf
            },
            success: function(response) {
                if (response.sql_short_text){
                    SQL_shortText_Cache[sql_id] = response.sql_short_text;      // Cachen Ergebnis
                    set_sql_title(id, response.sql_short_text);                 // Title setzen
                    // jQuery(".ui-tooltip-content").html(get_content(id, response.sql_short_text));         // bringt hintereinander alle Treffer
                }
            }
        });
    }
}

// Registriere Ajax-Callbacks an konkretes jQuery-Objekt
function bind_special_ajax_callbacks(obj) {
    obj.bind('ajax:success', function(){                                        // Komischerweise funktioniert hier obj.ajaxSuccess nicht ???
         if (obj.parents(".slick-cell").length > 0)                             // ajax wurde aus einer slickgrid-Zelle heraus aufgerufen
             save_new_cell_content(obj);                                        // unterstellen, dass dann auch der Inhalt dieser Zelle geändert sein könnte
     });
}

// einmaliges Binden der allgemeinen Ajax-Callbacks für Dokument
function bind_ajax_callbacks() {
    jQuery(document)
        .ajaxSend(function(event, jqXHR, ajaxOptions){
            closeAllTooltips();
            showIndicator();
        })
        .ajaxComplete(function(event, jqXHR, ajaxOptions){
            check_dom_for_duplicate_ids();
            hideIndicator();
        })
        .ajaxError(function(event, jqXHR, ajaxSettings, thrownError){
            jQuery("#error_dialog_content").html('Error : '+thrownError+'<br/>Status='+jqXHR.status+' ('+jqXHR.statusText+')<br/><br/>'+jqXHR.responseText);
            jQuery("#error_dialog").dialog("open");
        })
    ;
}


function trace_log(msg){
    if (show_trace_output){
        console.log(msg);                                                           // Aktivieren trace-Ausschriften
    }
}

// Zeichnen eines Diagrammes aus den übergebenen Datentupeln
// Parameter:
// Unique-ID fuer Bildung der Canvas-ID
// DOM-ID of DIV for plotting
// Kopfzeile
// Daten-Array
// multiple_y_axes  bool
// show_y_axes      bool
// x_axis_time      bool    Ist X-Achse ein Zeitstempel oder Nummer
function plot_diagram(unique_id, plot_area_id, caption, data_array, multiple_y_axes, show_y_axes, x_axis_time) {
    var plot_area = jQuery('#'+plot_area_id);

    function pad2(number){          // Vornullen auffuellen für Datum etc.
        var str=''+number;
        if (str.length < 2){
            str = '0' + str;
        }
        return str;
    }

    function remove_diagram(){      // Komplettes Diagramm entfernen
        plot_area.html("");                                  // Area putzen
    }

    var canvas_id = "canvas_" + unique_id;
    var head_id = "head_" + canvas_id;
    var canvas_height = 450;

    // interne Struktur des gegebenen DIV anlegen mit 2 DIVs
    plot_area
            .css("background-color", "white")
            .html('<div id="'+head_id+'" style="float:left; width:100%; background-color: white; padding-bottom: 5px;"></div>'+
                  '<div id="'+canvas_id+'" style="float:left; width:100%; height: '+canvas_height+'px; background-color: white; "></div>'
            );

    // Header-Bereich belegen
    jQuery('#'+head_id)
        .html('<div style="float:left; padding:3px;">'+caption+'</div><div align = "right"><input class="close_diagram_'+unique_id+'" type="button" title="Diagramm Schliessen" value="X"></div>')
        .css('margin-top', '5px')
        .find(".close_diagram_"+unique_id).click(function(){remove_diagram()});

    // Unterschiedliche IDs fuer Y-Achsen vergeben, wenn separat darzustellen
    jQuery.each(data_array, function(i,val){
        if (multiple_y_axes==true)
            val.yaxis = data_array.length-i;
        else
            val.yaxis = 1;
    });

    plot_options = {
        series:     {lines: { show: true }, points: { show: true }},
        crosshair:  { mode: "x" },
        grid:       { hoverable: true, autoHighlight: false },
        yaxis:      { min: 0, show: show_y_axes==true },
        legend:     { position: "ne"}
    };
    if (x_axis_time){
        plot_options["xaxes"] = [{ mode: 'time' }]
    }
    var plot = jQuery.plot(jQuery('#'+canvas_id), data_array, plot_options);     // Ausgabe des Diagrammes auf Canvas

    if (data_array.length == 0){
        return;                                   // Aufbereitung des Diagrammes verlassen wenn gar keine Daten zum Zeichnen
    }


    // ############ Context-Menü

    jQuery('#'+canvas_id).contextPopup({
         title: 'Diagramm',
         items: [
            {
                label: (show_y_axes==true ? "y-Achse(n) ausblenden" : "y-Achse(n) anzeigen"),
                icon: 'assets/application-monitor.png',
                action: function(){
                    plot_area.html(""); // Altes Diagramm entfernen
                    plot_diagram(unique_id, plot_area_id, caption, data_array, multiple_y_axes, (show_y_axes==true ? false : true), x_axis_time);
                }
            },
             {
                 label: (multiple_y_axes==true ? "Alle Kurven in einer y-Achse darstellen" : "Eigene y-Achse je Kurve (100% Wertebereich)"),
                 icon: 'assets/application-monitor.png',
                 action: function(){
                     plot_area.html(""); // Altes Diagramm entfernen
                     plot_diagram(unique_id, plot_area_id, caption, data_array, (multiple_y_axes==true ? false : true), show_y_axes, x_axis_time);
                 }
             }
         ]
    });

    // ############ crosshair.Anzeige aktualisieren
    var updateLegendTimeout = null;
    var latestPosition = null;

    var legends = jQuery('#'+canvas_id+" .legendLabel");
    legends.each(function () {
        // fix the widths so they don't jump around
        jQuery(this).css('width', jQuery(this).width()+10);
    });

    // Legendenzeile für X-Achse hinzufügen
    var x_legend_title;
    if (plot_options.xaxes[0].mode == "time"){
        x_legend_title = "Time";
    } else {
        x_legend_title = 'X';
    }
    jQuery('#'+canvas_id+" .legend").find("tbody").append("<tr><td align='center'>"+x_legend_title+"</td><td class='legendXAxis'></td></tr>");
    var legendXAxis =jQuery('#'+canvas_id+" .legendXAxis");

    // Titel zu Skalen der spalten hinzufuegen, wenn multiple y-Achsen angezeigt werden
    if (multiple_y_axes==true){

        jQuery.each(data_array, function(i,val){
            jQuery('#'+canvas_id+" .y"+(data_array.length-i)+"Axis").attr("title", val.label);
        });
    }

    function updateLegend() {
        updateLegendTimeout = null;
        var pos = latestPosition;

        var axes = plot.getAxes();
        if (pos.x < axes.xaxis.min || pos.x > axes.xaxis.max ||
            pos.y < axes.yaxis.min || pos.y > axes.yaxis.max)
            return;

        var i, j, dataset = plot.getData();
        for (i = 0; i < dataset.length; ++i) {
            var series = dataset[i];

            // find the nearest points, x-wise
            for (j = 0; j < series.data.length; ++j)
                if (series.data[j][0] > pos.x)
                    break;

            // now interpolate
            var y, p1 = series.data[j - 1], p2 = series.data[j];
            if (p1 == null)
                y = p2[1];
            else if (p2 == null)
                y = p1[1];
            else
                y = p1[1] + (p2[1] - p1[1]) * (pos.x - p1[0]) / (p2[0] - p1[0]);

            legends.eq(i).text(series.label + "= " + y.toFixed(2));
        }
        // Zeitpunkt des Crosshairs in X-Axis anzeigen
        if (plot_options.xaxes[0].mode == "time"){
            var time = new Date(pos.x);
            legendXAxis.html(pad2(time.getUTCDate())+"."+pad2(time.getUTCMonth()+1)+"."+time.getUTCFullYear()+" "+pad2(time.getUTCHours())+":"+pad2(time.getUTCMinutes()));   // Anzeige des aktuellen wertes der X-Achse
        } else {
            legendXAxis.html(pos.x);
        }
    }


    // ############ MouseOver-Hint Anzeige aktualisieren
    var previousToolTipPoint = null;
    var toolTipID = canvas_id+"_ToolTip"

    function showTooltip(x, y, contents) {
        $('<div id="'+toolTipID+'">' + contents + '</div>').css( {
            position: 'absolute',
            display: 'none',
            top: y + 5,
            left: x + 5,
            border: '1px solid #fdd',
            padding: '2px',
            'background-color': '#fee',
            opacity: 0.80
        }).appendTo("body").fadeIn(300);
    }


    // ############ Events binden
    jQuery('#'+canvas_id).bind("plothover",  function (event, pos, item) {
        latestPosition = pos;
        if (!updateLegendTimeout)
            updateLegendTimeout = setTimeout(updateLegend, 50);     // Zeitverzögertes Ausfrufen von updateLegend für crosshair und Aktualisierung Legende
        if (item) {
             if (previousToolTipPoint != item.dataIndex) {
                 previousToolTipPoint = item.dataIndex;
                 $("#"+toolTipID).remove();
                 // Label ist schon durch Crosshair mit Anfangs-Wert belegt, diesen durch aktuellen ersetzen
                 showTooltip(item.pageX, item.pageY, item.series.label + "= " + item.datapoint[1].toFixed(2)   );
             }
         }
         else {
            $("#"+toolTipID).remove();
             previousToolTipPoint = null;
         }

    });

    jQuery('#'+canvas_id+" .legend").draggable().css("left", -9).css("top", canvas_height*-1+9); // Legende verschiebbar gestalten, da dann mit position:relative gearbeitet wird, muss neu positioniert werden

} // plot_diagram

// Zeichnen eines Diagrammes mit den Daten einer table-Spalte
// Parameter:
// ID der Table
// ID des DIVs fuer Plotting
// Kopfzeile
// Name der Spalte, die ein/ausgeschalten wird
function plot_table_diagram(table_id, plot_area_id, caption, column_name, multiple_y_axes, show_y_axes) {

    function get_content(td_field){         // Ermitteln des html-Inhaltes einer TD-Zelle bzw. ihrer Kinder, wenn weitere enthalten sind
        var td_content;
        if (td_field.children().length > 0){     // <td> enthält Kinder
            td_content = td_field.children().html();
        } else {
            td_content = td_field.html();
        }
        return td_content;
    }

    function get_numeric_content(td_field){ // Ermitteln des numerischen html-Inhaltes einer TD-Zelle bzw. ihrer Kinder, wenn weitere enthalten sind
        var td_content = get_content(td_field);
        if (session_locale == 'de'){   // globale Variable session_locale wird gesetzt bei Anmeldung in EnvController.setDatabase
            td_content = parseFloat(td_content.replace(/\./g, "").replace(/,/,"."));   // Deutsche nach englische Float-Darstellung wandeln (Dezimatrenner, Komma)
        }
        if (session_locale == 'en'){   // globale Variable session_locale wird gesetzt bei Anmeldung in EnvController.setDatabase
            td_content = parseFloat(td_content.replace(/\,/g, ""));                   // Englische Float-Darstellung wandeln, Tausend-Separator entfernen
        }
        return td_content;
    }

    function get_date_content(td_field){ // Ermitteln des html-Inhaltes einer TD-Zelle bzw. ihrer Kinder, wenn weitere enthalten sind, als Date
        var parsed_field = get_content(td_field);
        if (session_locale == 'de'){
            var all_parts = parsed_field.split(" ");
            var date_parts = all_parts[0].split(".");
            parsed_field = date_parts[2]+"/"+date_parts[1]+"/"+date_parts[0]+" "+all_parts[1]   // Datum ISO neu zusammengsetzt + Zeit
        }
        if (session_locale == 'en'){
            parsed_field= parsed_field.replace(/-/g,"/");       // Umwandeln "-" nach "/", da nur so im Date-Konstruktor geparst werden kann
        }
        return new Date(parsed_field+" GMT");
    }

    //Sortieren eines DataArray nach dem ersten Element des inneren Arrays (X-Achse)
    function data_array_sort(a,b){
        return a[0] - b[0];
    }



    var columns = jQuery('#'+table_id).data('columns');     // JS-Objekt mit Spalten-Struktur gespeichert an DOM-Element

    // Spaltenheader der Spalte mit class 'plottable' versehen oder wegnehmen wenn bereits gesetzt (wenn Column geschalten wird)
    if (column_name && column_name != ""){                            // nur Aufrufen wenn column_name wirklich belegt ist
        if (columns[column_name]['plottable'] == 1) {
            columns[column_name]['plottable'] = 0;
        } else {
            columns[column_name]['plottable'] = 1;
        }

    }

    jQuery('#'+table_id).data('columns', columns);          // Rueckschreiben der Spalten-Info in DOM-Objekt

    var plot_master_column_index = null;                    // Spalten-Nr. der Plotmaster-Spalte
    var plot_master_time_column_index=null;                 // Spalten-Nr. der Plotmaster-Spalte, wenn diese Zeit als Inhalt hat
    var plotting_column_count = 0;          // Anzahl der zu zeichnenden Spalten
    var i = 0;
    for (var key in columns) {
        if (columns[key]['plot_master']){       // ermitteln der Spalte, die plot_master für X-Achse ist
            if (plot_master_column_index){ alert("Only one column may have attribute 'plot_master'");}
            plot_master_column_index = i;
        }
        if (columns[key]['plot_master_time']){              // ermitteln der Spalte, die plot_master für X-Achse ist mit Zeit als Inhalt
            if (plot_master_time_column_index){ alert("Only one column may have attribute 'plot_master_time'");}
            plot_master_column_index = i;
            plot_master_time_column_index=i;
        }
        if (columns[key]['plottable'] == 1){
            plotting_column_count++;
        }
        i++;
    }
    if (plot_master_column_index == null){
        alert('Fehler: Keine <th>-Spalte besitzt die Klasse "plot_master"! Exakt eine Spalte mit dieser Klasse wird erwartet');
    }

    var x_axis_time = false;       // Defaut, wenn keine plot_master_time gesetzt werden
    var data_array = [];
    var plotting_index = 0
    // Iteration ueber plotting-Spalten
    for (var key in columns) {
        var column = columns[key]                                          // konkretes Spalten-Objekt aus DOM
        if (column['plottable']==1){                              // nur fuer zu zeichnenden Spalten ausführen
            header_index = column   ['index']
            var col_data_array = [];
            // Iteration ueber alle Records der Tabelle
            var max_column_value = 0;               // groessten Wert der Spalte ermitteln für notwendige Breite der Anzeige
            jQuery('#'+table_id).find('tr').each(function(index, rec){
                if (index > 0) {                      // Ausblenden der Header-Zeile
                    var x_val = null;
                    var y_val = null;
                    // Aufbau eines Tupels aus Plot_master und plottable-Spalte
                    jQuery(rec).children('td').each(function(field_index, field){      // Iteration über Felder des Records, gesucht wird Index der aktuellen plottable-spalte
                        var td_field = jQuery(field);
                        if (field_index == header_index){
                            y_val = get_numeric_content(td_field);
                            if (y_val > max_column_value){              // groessten wert der Spalte ermitteln
                                max_column_value = y_val;
                            }
                        }
                        if (field_index ==plot_master_column_index){
                           if (field_index==plot_master_time_column_index){
                                x_val = get_date_content(td_field).getTime();       // Zeit in ms seit 1970
                                x_axis_time = true;       // mindestens ein plot_master_time gesetzt werden
                            } else {
                                x_val = get_numeric_content(td_field);
                            }
                        }
                    });
                    col_data_array.push( [ x_val, y_val ]);
                }
            });
            col_data_array.sort(data_array_sort);      // Data_Array der Spalte nach X-Achse sortieren
            col_attr = {label:columns[key]['caption'],
                        data: col_data_array
            }
            data_array.push(col_attr);   // Erweiterung des primären arrays
            plotting_index = plotting_index + 1;  // Weiterzaehlen Index
        }
    }


    plot_diagram(
        table_id,
        plot_area_id,
        caption,
        data_array,
        multiple_y_axes,
        show_y_axes,
        x_axis_time
    );
} // plot_table_diagram


// Zeichnen eines Diagrammes mit den Daten einer slickgrid-Spalte
// Parameter:
// ID der Table
// jQuery-Selector des DIVs fuer Plotting
// Kopfzeile
// Name der Spalte, die ein/ausgeschalten wird
function plot_slickgrid_diagram(table_id, plot_area_id, caption, column_id, multiple_y_axes, show_y_axes) {

    function get_numeric_content(celldata){ // Ermitteln des numerischen html-Inhaltes einer TD-Zelle bzw. ihrer Kinder, wenn weitere enthalten sind
        if (session_locale == 'de'){   // globale Variable session_locale wird gesetzt bei Anmeldung in EnvController.setDatabase
            return parseFloat(celldata.replace(/\./g, "").replace(/,/,"."));   // Deutsche nach englische Float-Darstellung wandeln (Dezimatrenner, Komma)
        }
        if (session_locale == 'en'){   // globale Variable session_locale wird gesetzt bei Anmeldung in EnvController.setDatabase
            return parseFloat(celldata.replace(/\,/g, ""));                   // Englische Float-Darstellung wandeln, Tausend-Separator entfernen
        }
        return "Error: unsupported locale "+session_locale;
    }

    function get_date_content(celldata){ // Ermitteln des html-Inhaltes einer TD-Zelle bzw. ihrer Kinder, wenn weitere enthalten sind, als Date
        var parsed_field;
        if (session_locale == 'de'){
            var all_parts = celldata.split(" ");
            var date_parts = all_parts[0].split(".");
            parsed_field = date_parts[2]+"/"+date_parts[1]+"/"+date_parts[0]+" "+all_parts[1]   // Datum ISO neu zusammengsetzt + Zeit
        }
        if (session_locale == 'en'){
            parsed_field= celldata.replace(/-/g,"/");       // Umwandeln "-" nach "/", da nur so im Date-Konstruktor geparst werden kann
        }
        return new Date(parsed_field+" GMT");
    }

    //Sortieren eines DataArray nach dem ersten Element des inneren Arrays (X-Achse)
    function data_array_sort(a,b){
        return a[0] - b[0];
    }



    var grid =  jQuery('#'+table_id);
    var columns = grid.data('slickgrid').getColumns();                          // JS-Objekt mit Spalten-Struktur gespeichert an DOM-Element, Originaldaten des Slickgrid, daher kein Speichern nötig
    var data    = grid.data('slickgrid').getData().getItems();                  // JS-Aray mit Daten-Struktur gespeichert an DOM-Element, Originaldaten des Slickgrid, daher kein Speichern nötig

    // Spaltenheader der Spalte mit class 'plottable' versehen oder wegnehmen wenn bereits gesetzt (wenn Column geschalten wird)
    for (var col_index in columns){
        if (columns[col_index]['id'] == column_id){
            if (columns[col_index]['plottable'] == 1)
                columns[col_index]['plottable'] = 0
            else
                columns[col_index]['plottable'] = 1
        }
    }

    var plot_master_column_index = null;                                        // Spalten-Nr. der Plotmaster-Spalte
    var plot_master_column_id = null;                                           // Spalten-Name der Plotmaster-Spalte
    var plot_master_time_column_index=null;                                     // Spalten-Nr. der Plotmaster-Spalte, wenn diese Zeit als Inhalt hat
    var plotting_column_count = 0;                                              // Anzahl der zu zeichnenden Spalten
    for (var column_index in columns) {
        var column = columns[column_index]                                      // konkretes Spalten-Objekt aus DOM
        if (column['plot_master']){                              // ermitteln der Spalte, die plot_master für X-Achse ist
            if (plot_master_column_index){ alert("Only one column may have attribute 'plot_master'");}
            plot_master_column_index = column_index;
            plot_master_column_id = column['id'];
        }
        if (column['plot_master_time']){                         // ermitteln der Spalte, die plot_master für X-Achse ist mit Zeit als Inhalt
            if (plot_master_time_column_index){ alert("Only one column may have attribute 'plot_master_time'");}
            plot_master_column_index = column_index;
            plot_master_column_id = column['id'];
            plot_master_time_column_index=column_index;
        }
        if (column['plottable'] == 1){
            plotting_column_count++;
        }
    }
    if (plot_master_column_index == null){
        alert('Fehler: Keine <th>-Spalte besitzt die Klasse "plot_master"! Exakt eine Spalte mit dieser Klasse wird erwartet');
    }

    var x_axis_time = false;                                                    // Defaut, wenn keine plot_master_time gesetzt werden
    var data_array = [];
    var plotting_index = 0
    // Iteration ueber plotting-Spalten
    for (var column_index in columns) {
        var column = columns[column_index]                                      // konkretes Spalten-Objekt aus DOM
        if (column['plottable']==1){                                            // nur fuer zu zeichnenden Spalten ausführen
            var col_data_array = [];
            // Iteration ueber alle Records der Tabelle
            var max_column_value = 0;                                           // groessten Wert der Spalte ermitteln für notwendige Breite der Anzeige
            for (var data_index in data){                                       // Iteration über Daten
                var x_val = null;
                var y_val = null;
                // Aufbau eines Tupels aus Plot_master und plottable-Spalte
                // Plottable-Spalte
                y_val = get_numeric_content(data[data_index][column['id']]);
                if (y_val > max_column_value)              // groessten wert der Spalte ermitteln
                    max_column_value = y_val;
                // Plot-Master-Spalte
                if (plot_master_time_column_index){
                    x_val = get_date_content(data[data_index][plot_master_column_id]).getTime();       // Zeit in ms seit 1970
                    x_axis_time = true;       // mindestens ein plot_master_time gesetzt werden
                } else {
                    x_val = get_numeric_content(data[data_index][plot_master_column_id]);
                }
                col_data_array.push( [ x_val, y_val ]);
            }
            col_data_array.sort(data_array_sort);      // Data_Array der Spalte nach X-Achse sortieren
            col_attr = {label:column['name'],
                        data: col_data_array
            }
            data_array.push(col_attr);   // Erweiterung des primären arrays
            plotting_index = plotting_index + 1;  // Weiterzaehlen Index
        }
    }


    plot_diagram(
        table_id,
        plot_area_id,
        caption,
        data_array,
        multiple_y_axes,
        show_y_axes,
        x_axis_time
    );
} // plot_slickgrid_diagram


// Ermitteln der Darstellungsbreite in Pixel einer Zeichenkette
function get_string_pixel_width(testdiv, string){
    testdiv.html(string);
    return testdiv.width()+4;
}



// Fangen des Resize-Events des Browsers und Anpassen der Breite aller slickGrids
function resize_slickGrids(){
    jQuery('.slickgrid_top').each(function(index, element){
        var grid = jQuery(element);
        if (grid.data('last_resize_width') && grid.data('last_resize_width') != grid.width() && grid.data('slickgrid')) { // nur durchrechnen, wenn sich wirklich Breite ändert und grid bereits initialisiert ist
            calculate_current_grid_column_widths(grid, "resize_slickGrids");
            grid.data('last_resize_width', grid.width());                       // persistieren Aktuelle Breite
        }
    });
}

// Ermitteln der Breite eines Scrollbars (nur einmal je Session wirklich ausführen, sonst gecachten wert liefern)
var scrollbarWidth_internal_cache = null;
function scrollbarWidth() {
    if (scrollbarWidth_internal_cache)
        return scrollbarWidth_internal_cache;
//    var div = $('<div style="width:50px;height:50px;overflow:hidden;position:absolute;top:-200px;left:-200px;"><div style="height:100px;"></div>');
    var div = $('<div style="width:50px;height:50px;overflow:scroll;"><div id="scrollbarWidth_testdiv">Hugo</div></div>');
    // Append our div, do our calculation and then remove it
    $('body').append(div);
    scrollbarWidth_internal_cache = div.width() - div.find("#scrollbarWidth_testdiv").width();
    $(div).remove();
    return scrollbarWidth_internal_cache;
}


// Dekorieren einer slickgrid-Zelle mit optionalen Werten
// TODO Statt eines DIV den äusseren DIV dekorieren
function decorateFormatter(row_number, value, columnDef, column_metadata){
    var output = "<div class='slick-inner-cell' row="+row_number+" column='"+columnDef['field']+"'";           // sichert u.a. 100% Ausdehnung im Parent und Wiedererkennung der Spalte bei Mouse-Events
    if (column_metadata['title']) {
        output += " title='"+column_metadata['title']+"'";
    } else {
        if (columnDef['toolTip'])
            output += " title='"+columnDef['toolTip']+"'";
    }
    var style = "";
    if (column_metadata['style'])
        style += column_metadata['style'];
    if (columnDef['style'])
        style += columnDef['style'];
    if (!columnDef['no_wrap'])
        style += "white-space: normal; ";
    if (style != "")
        output += " style='"+style+"'";
    output += ">"+value+"</div>"
    return output;
}

// Default-Formatter für Umsetzung HTML in SlickGrid
// Parameter: row-,cell-Nr. beginnend mit 0
//            value:        Wert der Zelle in data
//            columnDef:    Spaltendefinition
//            dataContext:  komplette Zeile aus data-Array
function HTMLFormatter(row, cell, value, columnDef, dataContext) {
    var column_metadata = dataContext['metadata']['columns'][columnDef['field']];  // Metadata der Spalte der Row
    var fullvalue = value;                                                      // wenn keine dekorierten Daten vorhanden sind, dann Nettodaten verwenden
    if (column_metadata['fulldata'])
        fullvalue = column_metadata['fulldata']                                 // Ersetzen des data-Wertes durch komplette Vorgabe incl. html-tags etc.

    if (!column_metadata['dc'] || column_metadata['dc']==0){                    // bislang fand noch keine Messung der Dimensionen der Zellen dieser Zeile statt
        calc_cell_dimensions(value, fullvalue, columnDef);                      // Werte ermitteln und gegen bislang bekannte Werte der Spalte testen
        column_metadata['dc'] = 1;                                              // Zeile als berechnet markieren
    }

    return decorateFormatter(row, fullvalue, columnDef, column_metadata);
}

var slickgrid_render_needed = 0;                                                // globale Variable, die steuert, ob aktuell gezeichnetes Grid nach Abschluss neu gerendert werden muss, da sich Größen geändert haben
var test_cell = null;                                                           // Objekt zum Test der realen string-Breite für td, wird bei erstem Zugriff initialisiert
var test_cell_wrap = null;                                                      // Objekt zum Test der realen string-Breite für td, wird bei erstem Zugriff initialisiert
// Ermitteln der Dimensionen aller Zellen der Zeile und Abgleich gegen bisherige Werte der Spalte
// Parameter: Zelle des data-Array
//            Zelle des metadata-Array
//            Column-Definition
function calc_cell_dimensions(value, fullvalue, column){
    if (!column['last_calc_value'] || (value != column['last_calc_value'] && value.length*9 > column['max_wrap_width'])){  // gleicher Wert muss nicht erneut gecheckt werden, neuer Wert muss > alter sein bei 10 Pixel Breite, aber bei erstem Male durchlauen
        if (!test_cell)
          test_cell = jQuery('#test_cell');                                     // Objekt zum Test der realen string-Breite für td, Initialisierung bei erstem Zugriff
        test_cell.html(fullvalue);                                              // Test-DOM nowrapped mit voll dekoriertem Inhalt füllen
        test_cell.attr('class', column['cssClass']);                            // Class ersetzen am Objekt durch aktuelle, dabei überschreiben evtl. vorheriger
        if (test_cell.prop("scrollWidth")  > column['max_nowrap_width']){
            column['max_nowrap_width']  = test_cell.prop("scrollWidth");
            slickgrid_render_needed = 1;
        }
        if (!column['no_wrap']  && test_cell.prop("scrollWidth") > column['max_wrap_width']){     // Nur Aufrufen, wenn max_wrap_width sich auch vergrößern kann (aktuelle Breite > bisher größte Wrap-Breite)
            if (!test_cell_wrap)
              test_cell_wrap    = jQuery('#test_cell_wrap');                    // Objekt zum Test der realen string-Breite für td
            test_cell_wrap.html(fullvalue);                                     // Test-DOM wrapped mit voll dekoriertem Inhalt füllen
            test_cell_wrap.attr('class', column['cssClass']);                   // Class ersetzen am Objekt durch aktuelle, dabei überschreiben evtl. vorheriger
            if (test_cell_wrap.width()  > column['max_wrap_width']){
//console.log("Column "+column['name']+" NewWrapWidth="+test_cell_wrap.width()+ " "+value+ " prevWrapWidth="+column['max_wrap_width'])
                column['max_wrap_width']  = test_cell_wrap.width();
                slickgrid_render_needed = 1;
            }
            if (fullvalue != value)                                             // Enthält Zelle einen mit tags dekorierten Wert ?
                test_cell_wrap.html("");                                        // leeren der Testzelle, wenn fullvalue weitere html-tags etc. enthält, ansonsten könnten z.B. Ziel-DOM-ID's mehrfach existierem
        }
        if (fullvalue != value)                                                 // Enthält Zelle einen mit tags dekorierten Wert ?
            test_cell.html("");                                                 // leeren der Testzelle, wenn fullvalue weitere html-tags etc. enthält, ansonsten könnten z.B. Ziel-DOM-ID's mehrfach existierem
        column['last_calc_value'] = value;                                      // Merken an Spalte für nächsten Vergleich
    }
}

// Ermittlung der Zeilenhöhe fuer einzeilige Darstellung
function single_line_height() {
    return jQuery('#test_cell').html("1").height();
}

// Speichern Inhalt und Erneutes Berechnen der Breite und Höhe einer Zelle nach Änderung ihres Inhaltes + Aktualisieren der Anzeige, um kompletten neuen Content zeigen zu können (nicht abgeschnitten)
// Parameter: jQuery-Objekt auf dem innerhalb einer Zelle ein ajax-Call ausgelöst wurde
function save_new_cell_content(obj){
    var inner_cell = obj.parents(".slick-inner-cell");
    var grid_table = inner_cell.parents(".slickgrid_top");                      // Grid-Table als jQuery-Objekt
    var grid = grid_table.data("slickgrid");
    if (!grid){
        console.log("No slickgrid found in data for "+inner_cell.html());
        return;
    }
    var column = null;
    for (var column_index in grid.getColumns()){
        if (grid.getColumns()[column_index]['field'] == inner_cell.attr('column'))
            column = grid.getColumns()[column_index];
    }
    // Rückschreiben des neuen Dateninhaltes in Metadata-Struktur des Grid
    grid.getData().getItems()[inner_cell.attr("row")][inner_cell.attr("column")] = inner_cell.text();  // sichtbarer Anteil der Zelle
    grid.getData().getItems()[inner_cell.attr("row")]["metadata"]["columns"][inner_cell.attr("column")]["fulldata"] = inner_cell.html(); // Voller html-Inhalt der Zelle

    calc_cell_dimensions(inner_cell.text(), inner_cell.html(), column);         // Neu-Berechnen der max. Größen durch getürkten Aufruf der Zeichenfunktion
    calculate_current_grid_column_widths(grid_table, 'recalculate_cell_dimension'); // Neuberechnung der Zeilenhöhe, Spaltenbreite etc. auslösen, auf jeden Fall, da sich die Höhe verändert haben kann
}


function processColumnsResized(grid){
    for (var col_index in grid.getColumns()){
        var column = grid.getColumns()[col_index];
        if (column['previousWidth'] != column['width']){                        // Breite dieser Spalte wurde resized durch drag
            column['fixedWidth'] = column['width'];                             // Diese spalte von Kalkulation der Spalten ausnehmen
        }
    }
    grid.getOptions()["rowHeight"] = 1;                                         //Neuberechnung der wirklich benötigten Höhe auslösen
    calculate_current_grid_column_widths(jQuery(grid.getCanvasNode()).parents(".slickgrid_top"), "processColumnsResized");
    //grid.render();                                                              // Grid neu berechnen und zeichnen
}


// Parsen eines numerischen Wertes aus der landesspezifischen Darstellung mit Komma und Dezimaltrenner
function parseFloatLocale(value){
    if (value == "")
        return 0;
    if (session_locale == 'en'){                                        // globale Variable session_locale wird gesetzt bei Anmeldung in EnvController.setDatabase
        return parseFloat(value.replace(/\,/g, ""));
    } else {
        return parseFloat(value.replace(/\./g, "").replace(/,/,"."));
    }
}

// Setzen/Limitieren der Höhe des Grids auf maximale Höhe des Inhaltes
// Parameter: jQuery-Objekt des Grid-Containers
function adjust_real_grid_height(jq_container){
    // Einstellen der wirklich notwendigen Höhe des Grids (einige Browser wie Safari brauchen zum Aufbau des Grids Plastz für horizontalen Scrollbar, auch wenn dieser am Ende nicht sichtbar wird
    var total_height = jq_container.data('total_height');                       // gespeicherte Inhaltes-Höhe aus calculate_current_grid_column_widths
    if (total_height < jq_container.height())                                   // Sicherstellen, dass Höhe des Containers nicht größer als Höhe des Grids mit allen Zeilen sichtbar
        jq_container.height(total_height);
}

// Justieren des Grids nach Abshcluss der Resize-Operation mit unterem Schieber
function finish_vertical_resize(jg_container){
    calculate_current_grid_column_widths(jg_container, 'finish_vertical_resize');  // Neuberechnen breiten (neue Situation bzgl. vertikalem Scrollbar)
    adjust_real_grid_height(jg_container);                                      // Limitieren Höhe
}


function grid2CSV(grid_id) {
    var grid_div = jQuery("#"+grid_id);
    var grid = grid_div.data("slickgrid");
    var data = "";

    function escape(cell){
        return cell.replace(/"/g,"\\\"").replace(/'/g,"\\\'").replace(/;/g, "\\;");
    }

    //Header
    grid_div.find(".slick-header-columns").children().each(function(index, element) {
        data += '"'+escape(jQuery(element).text())+'";'
    });
    data += "\n";

    // Zellen
    var grid_data    = grid.getData().getItems();
    var grid_columns = grid.getColumns();

    for (data_index in grid_data){
        for (col_index in grid_columns){
            data += '"'+escape(grid_data[data_index][grid_columns[col_index]['field']])+'";'
        }
        data += "\n"
    }

    if (navigator.appName.indexOf("Explorer") != -1)                            // Internet Explorer
        document.location.href = 'data:Application/octet-stream,' + encodeURIComponent(data);
     else {
        document.location.href = 'data:Application/download,' + encodeURIComponent(data);
    }
}

// Anzeige der Statistik aller Zeilen der Spalte (Summe etc.)
function show_column_stats(grid, column_name){
    var column = grid.getColumns()[grid.getColumnIndex(column_name)];
    var data   = grid.getData().getItems();
    var sum   = 0;
    var count = 0;
    var distinct = {};
    var distinct_count = 0;
    for (var row_index in data){
        sum += parseFloatLocale(data[row_index][column_name])
        count ++;
        distinct[data[row_index][column_name]] = 1;     // Wert in hash merken
    }
    for (var i in distinct) {
        distinct_count += 1;
    }
    alert("Sum = "+sum+"\nCount = "+count+"\nCount distinct = "+distinct_count);
}

// Anzeige des kompletten Inhaltes der Zelle
function show_full_cell_content(content){
    alert(content);
}

// Testen, ob DOM-Objekt vertikalen Scrollbar besitzt
// Parameter: jQuery-Objekt des grids
function has_slickgrid_vertical_scrollbar(grid_table){
    var viewport = grid_table.find(".slick-viewport");
    var scrollHeight = viewport.prop('scrollHeight');
    var clientHeight = viewport.prop('clientHeight');
    // Test auf vertikalen Scrollbar nur vornehmen, wenn clientHeight wirklich gesetzt ist und dann Differenz zu ScrollHeight
    return clientHeight > 0 && scrollHeight != clientHeight;
}


// Berechnung der aktuell möglichen Spaltenbreiten in Abhängigkeit des Parent und anpassen slickGrid
// Diese Funktion muss gegen rekursiven Aufruf geschützt werden,recursive from Height set da sie durch diverse Events getriggert wird
// Parameter: jQuery-Object der Table, Herkunfts-String
function calculate_current_grid_column_widths(grid_table, caller){
    var grid = grid_table.data('slickgrid');
    var options = grid.getOptions();

    var current_grid_width = grid_table.parent().prop('clientWidth');           // erstmal maximale Breit als Client annehmen, wird für auto-Breite später auf das notwendige reduziert
    var columns = grid.getColumns();
    var columns_changed = false;
    var max_table_width = 0;                                                    // max. Summe aller Spaltenbreiten (komplett mit Scrollbereich)
    var wrapable_count  = 0;                                                    // aktuelle Anzahl noch umzubrechender Spalten
    var column_count    = columns.length;                                       // Anzahl Spalten
    var column;
    var h_padding       = 10;                                                   // Horizontale Erweiterung der Spaltenbreite: padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)

    trace_log("start calculate_current_grid_column_widths "+caller);

    for (var col_index in columns) {
        column = columns[col_index];
        if (column['fixedWidth']){
            if (column['width'] != column['fixedWidth']) {                      // Feste Breite vorgegeben ?
                column['width']      = column['fixedWidth'];                    // Feste Breite der Spalte beinhaltet bereits padding
                columns_changed = true;
            }

        } else {                                                                // keine feste Breite vorgegeben
            if (column['width'] != column['max_nowrap_width']+h_padding) {
                column['width']      = column['max_nowrap_width']+h_padding;    // per Default komplette Breite des Inhaltes als Spaltenbreite annehmen , Korrektur um padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)
                columns_changed = true;
            }
        }

        max_table_width += column['width'];
        if (column['max_wrap_width'] < column['max_nowrap_width'] && !column['no_wrap'])
            wrapable_count += 1;
    }
    // Prüfen auf Möglichkeit des Umbruchs in der Zelle
    var current_table_width = max_table_width                                   // Summe aller max. Spaltenbreiten
    if (has_slickgrid_vertical_scrollbar(grid_table))
        current_table_width += scrollbarWidth();
    while (current_table_width > current_grid_width && wrapable_count > 0){     // es könnten noch weitere Spalten umgebrochen werden und zur Verringerung horiz. Scrollens dienen
        var min_wrap_diff = 1000000;                                            // kleinste Differenz
        var wrap_column  = null;                                                // sollte definitiv noch belegt werden
        for (var col_index in columns) {
            column = columns[col_index];
            var max_wrap_width = column['max_wrap_width']+h_padding;
            var width          = column['width'];
            if (max_wrap_width < width                  &&                      // Differenz existiert und ist kleiner als bisher je Spalte gesehene
                width-max_wrap_width < min_wrap_diff    &&
                !column['fixedWidth']                   &&                      // keine feste Breite der Spalte vorgegeben
                !column['no_wrap']){                                            // Wrap der spalte nicht ausgeschlossen
                min_wrap_diff  = width-max_wrap_width;                          // merken der kleinsten Differenz
                wrap_column = column;                                           // merken der Spalte mit kleinster Differenz
            }
        }
        if (wrap_column){                                                       // Es wurde noch eine zu wrappende Spalte gefunden
            if (current_table_width-min_wrap_diff < current_grid_width){        // Wrappen der Spalte macht Tabelle kleiner als mögliche Breite wäre
                wrap_column['width'] = wrap_column['width'] - (current_table_width - current_grid_width)  // Wrappen der Spalte nur um notwendigen Bereich
                min_wrap_diff = current_table_width - current_grid_width        // reduziert auf wirkliche Reduzierung
            } else {
                wrap_column['width'] = wrap_column['max_wrap_width']+h_padding; // padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)
            }
            current_table_width -= min_wrap_diff;
        }
        wrapable_count--;
    }
    // Evtl. Zoomen der Spalten wenn noch mehr Platz rechts vorhanden
    if (options['width'] == '' || options['width'] == '100%'){                  // automatische volle Breite des Grid
        while (current_table_width < current_grid_width){                       // noch Platz am rechten Rand, kann auch nach wrap einer Spalte verbleiben
            for (var col_index in columns) {
                if (current_table_width < current_grid_width && !columns[col_index]['fixedWidth']){
                    columns[col_index]['width']++;
                    current_table_width++;
                    columns_changed = true;
                }
            }
        }
    } else {                                                                    // auto-width
        var sort_pfeil_width = 10;
        for (var col_index in columns) {
            if (current_table_width < current_grid_width && !columns[col_index]['fixedWidth']){
                columns[col_index]['width'] += sort_pfeil_width;                // erweitern um Darstellung des Sort-Pfeiles
                current_table_width += sort_pfeil_width;
                max_table_width += sort_pfeil_width;                            // max. Breite des Grids im auto-Modus
                columns_changed = true;
            }
        }
    }

    grid_table.data('last_resize_width', grid_table.width());                   // Merken der aktuellen Breite, um unnötige resize-Events zu vermeiden

    var vertical_scrollbar_width = 0;
    if (has_slickgrid_vertical_scrollbar(grid_table))
        vertical_scrollbar_width = scrollbarWidth();
    if (options['width'] == "auto" && max_table_width+vertical_scrollbar_width < grid_table.parent().width() ) {     // Grid kann noch breiter dargestellt werden
        grid_table.css('width', max_table_width+vertical_scrollbar_width);  // Gesamtes Grid auf die Breite des Canvas (Summe aller Spalten) setzten
    }

    jQuery('#caption_'+grid_table.attr('id')).css('width', grid_table.width()); // Breite des Caption-Divs auf Breite des Grid setzen
    grid.setOptions(options);                                                   // Setzen der veränderten options am Grid
    if (columns_changed)
        grid.setColumns(columns);                                               // Setzen der veränderten Spaltenweiten am slickGrid, löst onScroll-Ereignis aus mit wiederholtem aufruf dieser Funktion, daher erst am Ende setzen

    //############### Ab hier Berechnen der Zeilenhöhen ##############
    var header_height = options['headerHeight']                                 // alter Wert
    var row_height    = options['rowHeight']                                    // alter Wert
    var v_padding     = 4;                                                      // Vertiale Erweiterung der Spaltenhöhe um Padding
    var horizontal_scrollbar_width = 0
    if (current_table_width+vertical_scrollbar_width > grid_table.parent().width() )   // nuss horizontaler Scrollbar existieren?
        horizontal_scrollbar_width = scrollbarWidth();

    // Hoehen von Header so setzen, dass der komplette Inhalt dargestellt wird
    grid_table.find(".slick-header-columns").children().each(function(){
        var scrollHeight = jQuery(this).prop("scrollHeight");
        var clientHeight = jQuery(this).prop("clientHeight");
        if (scrollHeight > clientHeight && scrollHeight-4 > header_height){     // Inhalt steht nach unten über
            header_height = scrollHeight-4;                                     // Padding hinzurechnen, da Höhe auf Ebene des Zeilen-DIV gesetzt wird
        }
    });

    if (options["line_height_single"]){
        row_height = single_line_height() + 8;
    } else {                                                                    // Volle notwendige Höhe errechnen
        // Hoehen von Cell so setzen, dass der komplette Inhalt dargestellt wird
        grid_table.find(".slick-inner-cell").each(function(){
            var scrollHeight = jQuery(this).prop("scrollHeight");

            if (scrollHeight > row_height+v_padding){                           // Inhalt steht nach unten über
                       row_height = scrollHeight+6;                             // Padding hinzurechnen, da Höhe auf Ebene des Zeilen-DIV gesetzt wird
            }

        });
    }

    if (row_height != options['rowHeight'] || header_height != options['headerHeight']){
        options['rowHeight']    = row_height;
        options['headerHeight'] = header_height;
        //calculate_current_grid_column_widths(grid_table, "recursive from Height set");

        var total_height =      options['headerHeight']                         // innere Höhe eines Headers
                              + 8                                               // padding top und bottom=4 des Headers
                              + 2                                               // border=1 top und bottom des headers
                              + (options['rowHeight'] * grid.getDataLength() )  // Höhe aller Datenzeilen
                              + horizontal_scrollbar_width
                              + (options["showHeaderRow"] ? options["headerRowHeight"] : 0)
                              ;                                                 // Linie über und unter dem Scrollbar

        grid_table.data('total_height', total_height);                          // Speichern am DIV-Objekt für Zugriff aus anderen Funktionen

        //console.log("Height calculation:");
        //console.log("margin="+(grid_table.outerHeight(true) - grid_table.outerHeight()));
        //console.log("header="+options['headerHeight']);
        //console.log("padding header=8");
        //console.log("rowheight="+options['rowHeight']);
        //console.log("Scrollbar="+scrollbarWidth());
        //console.log("totalcanvas="+(options['rowHeight']) * grid.getDataLength());
        //console.log("total_height="+total_height);

        var final_height = total_height+scrollbarWidth();                      // Höhe des Grids nach Abschluss der Operationen

        if (options['maxHeight'] && options['maxHeight'] < total_height)
            final_height = options['maxHeight'];                                // Limitieren der Höhe auf Vorgabe wenn sonst überschritten

        grid_table.height(final_height);                                        // Grid immer mit zusätzlicher Scrollbar-Höhe aufbauen

        grid.setOptions(options);                                               // Setzen der veränderten options am Grid
        grid.setColumns(columns);                                               // Setzen der veränderten Spaltenweiten am slickGrid, löst onScroll-Ereignis aus mit wiederholtem aufruf dieser Funktion, daher erst am Ende setzen
    }
    trace_log("end calculate_current_grid_column_widths "+caller);
}

// Ein- / Ausblenden der Filter-Inputs in Header-Rows des Slickgrids
function switch_slickgrid_filter_row(grid, grid_table){
    var options = grid.getOptions();
    if (options["showHeaderRow"]) {
        grid.setHeaderRowVisibility(false);
        grid.getData().setFilter(null);
    } else {
        grid.setHeaderRowVisibility(true);
        grid.getData().setFilter(options["searchFilter"]);
    }
    grid.setColumns(grid.getColumns());                                         // Auslösen/Provozieren des Events onHeaderRowCellRendered für slickGrid
    calculate_current_grid_column_widths(grid_table, "switch_slickgrid_filter_row");  // Höhe neu berechnen
}





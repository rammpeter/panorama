"use strict";

// Zeichnen eines Diagrammes auf Basis des flot-Pugins
// Peter Ramm, 25.10.2015


// Faktory-Methode zur Erzeugung und Initialisierung eines Objektes
// Parameter:
// Unique-ID fuer Bildung der Canvas-ID
// DOM-ID of DIV for plotting
// Kopfzeile
// Daten-Array
// Options: mehrdimensionales Object, Inhalte werden durchgereicht bis zur Methode "plot" des flot.old-Plugins
//   Defaults sind:
//      plot_diagram:   { locale: "en" }}
//      plot_diagram:   { multiple_y_axes: false}}  // mehrere y-Achsen anzeigen?
//      xaxes:          [{ mode: 'time'}],      // Ist X-Achse ein Zeitstempel oder Nummer
//      yaxis:          { show: true },         // Anzeige der Y-Achse
//      series:         {lines: { show: true }, points: { show: true }},

//   Weitere Einstellungen fuer options
//      yaxis:          { min: 0 }              // Minimaler Wert
//      selection: {
//                 mode: "x",
//                 color: 'gray',
//                 //shape: "round" or "miter" or "bevel",
//                 shape: "bevel",
//                 minSize: 4
//      }
//      legend: {
//                  labelFormatter: function with labelFormatter for legend: (label, series) => { return '<a href="#' + label + '">' + label + '</a>'; }
//      }
//      plotselected_handler:   function(start, end) with parameters as ms since 1970: (xstart, xend)=>{ ... }

function plot_diagram(unique_id, plot_area_id, caption, data_array, options){
    let p = new plot_diagram_class(unique_id, plot_area_id, caption, data_array, options);
    p.initialize();
    return p;
}

function plot_diagram_class(unique_id, plot_area_id, caption, data_array, options) {
    var plot_area               = jQuery('#'+plot_area_id);
    var canvas_id               = "canvas_" + unique_id;
    var head_id                 = "head_" + canvas_id;
    var updateLegendTimeout     = null;
    var latestPosition          = null;
    var legend_values           = null;         // Liste der letzten Spalten der Legende für Werte
    var legend_indexes          = {};           // Hash mit 'legend-name': index in Legende
    var legendXAxis             = null;         // erzeugt in initialize
    var previousToolTipPoint    = null;
    var toolTipID               = canvas_id+"_ToolTip";
    var plot                    = null;           //jQuery.plot(jQuery('#'+canvas_id), erzeugt in intialize()

    // Initialisierung des Objektes, ab jetzt ist this gültig
    this.initialize = function(){
        // options mit Defaults versehen
        if (options === undefined)
            options = {};


        var default_options = {
            plot_diagram:   { locale: 'en', multiple_y_axes: false },
            series:         {stack: false, lines: { show: true, fill: false }, points: { show: true }},
            crosshair:      { mode: "x" },
            grid:           { hoverable: true, autoHighlight: false },
            yaxis:          { show: true },
            xaxes:          [{ mode: 'time'}],
            legend:         { position: "ne"},
            canvas_height:  450
        };

        // Punkte für Werte nicht anzeigen, wenn mehr als x Einzelwerte auf x-Achse
        jQuery.each(data_array, function(i,val){
            if (val.data.length > 100)
                default_options.series.points.show = false;
        });

        /* deep merge defaults and options, without modifying defaults */
        options = jQuery.extend(true, {}, default_options,options);

        // interne Struktur des gegebenen DIV anlegen mit 2 DIVs
        plot_area
            .css("background-color", "white")
            .addClass('plot_diagram')               // Ermitteln aller aktiven Diagramme
            .data('plot_diagram', this)             // Zugriff auf Objekt über DOM
            .html('<div id="'+head_id+'" class="slick-shadow" style="float:left; width:100%; background-color: white; padding-bottom: 5px;"></div>'+
            '<div id="'+canvas_id+'" class="slick-shadow" style="float:left; width:100%; height: '+options.canvas_height+'px; background-color: white; margin-bottom: 10px; "></div>'
        )
            .resize(function(){ resize_plot_diagrams();});     // Registrieren fuer Event
        // Header-Bereich belegen
        jQuery('#'+head_id)
            .html('<div style="float:left; padding:3px;">'+caption+'</div><div align = "right"><input class="close_diagram_'+unique_id+'" type="button" title="Diagramm Schliessen" value="X"></div>')
            .css('margin-top', '5px')
            .find(".close_diagram_"+unique_id).click(function(){remove_diagram()});

        // Unterschiedliche IDs fuer Y-Achsen vergeben, wenn separat darzustellen
        jQuery.each(data_array, function(i,val){
            if (options.plot_diagram.multiple_y_axes===true)
                val.yaxis = data_array.length-i;
            else
                val.yaxis = 1;
        });

        let canvas = jQuery('#'+canvas_id);
        plot = jQuery.plot(canvas, data_array, options);     // Ausgabe des Diagrammes auf Canvas

        // bind plotselected handler to canvas for horizontal (x) selection
        if (options.plotselected_handler){
            canvas.bind( "plotselected", ( event, ranges)=>{
                options.plotselected_handler(ranges.xaxis.from, ranges.xaxis.to);
            });
        }

        // canvas durch Schieber am unteren Ende horizontal resizable gestalten
        canvas.resizable({});
        canvas.find(".ui-resizable-e").remove();                    // Entfernen des rechten resizes-Cursors
        canvas.find(".ui-resizable-se").remove();                   // Entfernen des rechten unteren resize-Cursors

        if (data_array.length === 0){
            return;                                   // Aufbereitung des Diagrammes verlassen wenn gar keine Daten zum Zeichnen
        }


        // ############ Context-Menü

        var context_menu_id = "menu_"+canvas_id;
        var menu = jQuery("<div class='contextMenu' id='"+context_menu_id+"' style='display:none;'>").insertAfter('#'+canvas_id);
        var ul   = jQuery("<ul></ul>").appendTo(menu);
        jQuery("<div id='header_"+context_menu_id+"' style='padding: 3px; background-color:lightgray;' align='center'>Diagram</div>").appendTo(ul);
        var bindings = {};

        function context_menu_entry(name, icon_class, label, hint, click_action ){
            jQuery("<li id='"+context_menu_id+"_"+name+"' title='"+hint+"'><span class='"+icon_class+"' style='float:left'>&nbsp;</span><span id='"+context_menu_id+"_"+name+"_label'>"+label+"</span></li>").appendTo(ul);
            bindings[context_menu_id+"_"+name] = click_action;
        }

        context_menu_entry(
            'y_axis',
            "cui-expand-left",
            options.yaxis.show===true ? locale_translate('diagram_y_axis_hide_name') : locale_translate('diagram_y_axis_show_name'),
            options.yaxis.show===true ? locale_translate('diagram_y_axis_hide_hint') : locale_translate('diagram_y_axis_show_hint'),
            function(t){
                plot_area.html(""); // Altes Diagramm entfernen
                options.yaxis.show = !options.yaxis.show;
                plot_diagram(unique_id, plot_area_id, caption, data_array, options);
            }
        );

        context_menu_entry(
            'all_in_one',
            'cui-sort-numeric-up',
            options.plot_diagram.multiple_y_axes===true ? locale_translate('diagram_all_on_name') : locale_translate('diagram_all_off_name'),
            options.plot_diagram.multiple_y_axes===true ? locale_translate('diagram_all_on_hint') : locale_translate('diagram_all_off_hint'),
            function(t){
                plot_area.html(""); // Altes Diagramm entfernen
                options.plot_diagram.multiple_y_axes = !options.plot_diagram.multiple_y_axes;
                plot_diagram(unique_id, plot_area_id, caption, data_array, options);
            }
        );

        context_menu_entry(
            'stack',
            'cuis-chart-area',
            options.series.stack===true ? locale_translate('diagram_unstack_name') : locale_translate('diagram_stack_name'),
            options.series.stack===true ? locale_translate('diagram_unstack_hint') : locale_translate('diagram_stack_hint'),
            function(t){
                plot_area.html(""); // Altes Diagramm entfernen
                options.series.stack = !options.series.stack;
                options.series.lines.fill = options.series.stack;
                if (options.series.stack)
                    options.plot_diagram.multiple_y_axes = false;
                plot_diagram(unique_id, plot_area_id, caption, data_array, options);
            }
        );

        context_menu_entry(
            'point',
            'cui-options',
            options.series.points.show===true ? locale_translate('diagram_hide_points_name') : locale_translate('diagram_show_points_name'),
            options.series.points.show===true ? locale_translate('diagram_hide_points_hint') : locale_translate('diagram_show_points_hint'),
            function(t){
                plot_area.html(""); // Altes Diagramm entfernen
                options.series.points.show = !options.series.points.show;
                plot_diagram(unique_id, plot_area_id, caption, data_array, options);
            }
        );

//        context_menu_entry(
//            'save',
//            "cui-disk",
//            locale_translate('diagram_save_to_image_name'),
//            locale_translate('diagram_save_to_image_hint'),
//            function(t){
//                var myCanvas = plot.getCanvas();
//                var image = myCanvas.toDataURL("image/png").replace("image/png", "image/octet-stream");  /// here is the most important part because if you dont replace you will get a DOM 18 exception.
//                document.location.href=image;
//            }
//        );

        jQuery('#'+canvas_id).contextMenu(context_menu_id, {
            menuStyle: {  width: '330px' },
            bindings:   bindings,
            onContextMenu : function(event, menu)                               // dynamisches Anpassen des Context-Menü
            {
                var cell = $(event.target);
                return true;
            }
        });


        this.registerLegend();                                                  // erstmaliger Aufruf, des weiteren neuer Aufruf nach Resize
        return plot;                                                            // get the original flot chart
    };   // end initialize

    this.get_plot = function(){
        return plot;
    }


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

    // ############ MouseOver-Hint Anzeige aktualisieren
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


    function updateLegend() {
        updateLegendTimeout = null;
        var pos = latestPosition;

        var axes = plot.getAxes();
        if (pos.x < axes.xaxis.min || pos.x > axes.xaxis.max ||
            pos.y < axes.yaxis.min || pos.y > axes.yaxis.max)
            return;

        var i, j, dataset = plot.getData();
        for (i = 0; i < dataset.length; ++i) {                                  // Iteration ueber die Kurven des Diagramms
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

            // Index des Labels in Legende aus legend_indexes lesen und dort Wert platzieren (Sortierung der Legende kann variieren)
            jQuery(legend_values[legend_indexes[series.label]]).html(y.toFixed(2));
        }
        // Zeitpunkt des Crosshairs in X-Axis anzeigen
        if (options.xaxes[0].mode === "time"){
            var time = new Date(pos.x);
            legendXAxis.html(pad2(time.getUTCDate())+"."+pad2(time.getUTCMonth()+1)+"."+time.getUTCFullYear()+" "+pad2(time.getUTCHours())+":"+pad2(time.getUTCMinutes())+':'+pad2(time.getUTCSeconds()));   // Anzeige des aktuellen wertes der X-Achse
        } else {
            legendXAxis.html(pos.x);
        }
    }

    this.registerLegend = function(){
        updateLegendTimeout = null;                                             // Sicherstellen, dass Timeout neu aufgeseztz wird

        // ############ Events binden
        jQuery('#'+canvas_id).bind("plothover",  function (event, pos, item) {
            latestPosition = pos;
            if (!updateLegendTimeout)
                updateLegendTimeout = setTimeout(updateLegend, 50);     // Zeitverzögertes Ausfrufen von updateLegend für crosshair und Aktualisierung Legende
            if (item) {
                if (previousToolTipPoint !== item.dataIndex) {
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


        // ############ crosshair.Anzeige aktualisieren

        // Legendenzeile für X-Achse hinzufügen
        var x_legend_title;
        if (options.xaxes[0].mode === "time"){
            x_legend_title = "Time";
        } else {
            x_legend_title = 'X';
        }

        var legend_div = jQuery('#'+canvas_id+" .legend");

        legend_div.children('div').detach();                                    // Entfernen eines Div ohne Funktion vor der legend_table, das sonst in der Größe mitgerführt werden müsste
        legend_div.find("table").addClass('legend_table');
        if (jQuery('#'+canvas_id+" .legendXAxis").length === 0) {                // bei erstmaligem aufruf Zeile hinzufügen, nicht bei jedem Resize

            // Spalte zufügen für die Werte-Anzeige und für Schliesser
            legend_div.find("tr").each(function(index, elem){
                var tr = jQuery(elem);
                var legend_name = jQuery(tr.children('td')[1]).text();          // strip possible decoration from labelFormatter
                legend_indexes[legend_name] = index;                            // Position zum Name der Kurve in der Legende merken
                tr.append("<td align='right' class='legend_value'></td>");

                //var escaped_legend_name = $("<div>").text(legend_name).html();
                tr.append("<td><a href='#' title='"+locale_translate('diagram_remove_chart')+"' style='color:red' onclick='delete_single_plot_chart(\""+plot_area_id+"\", "+index+"); return false;'>X</a></td>");
            });

            // Zeile für Anzeige des Zeitstempels zufügen
            legend_div.find("tbody").append("<tr><td></td><td>" + x_legend_title + "</td><td class='legendXAxis'></td><td></td></tr>");
        }
        legendXAxis         = jQuery('#'+canvas_id+" .legendXAxis");             // merken für wiederholte Verwendung
        legend_values       = jQuery('#'+canvas_id+" .legend_value");            // Liste der letzten Spalten merken für wiederholte Verwendung

        // Titel zu Skalen der spalten hinzufuegen, wenn multiple y-Achsen angezeigt werden
        if (options.plot_diagram.multiple_y_axes===true){

            jQuery.each(data_array, function(i,val){
                jQuery('#'+canvas_id+" .y"+(data_array.length-i)+"Axis").attr("title", val.label);
            });
        }

//        jQuery('#'+canvas_id+" .legend").draggable().css("left", -9).css("top", canvas_height*-1+9); // Legende verschiebbar gestalten, da dann mit position:relative gearbeitet wird, muss neu positioniert werden
        legend_div.draggable();
    };

    this.delete_single_chart = function(legend_index){

        // ermitteln des legenden-Namen über Index in table
        var legend_name = '';
        jQuery.each(legend_indexes, function(index, value){
            if (value === legend_index){
                legend_name = index;
            }
        });

        //if (!confirm(locale_translate('diagram_remove_chart_confirm')+' "'+legend_name+'"?' ) )
        //    return;

        // Finden der korrespondierenden Kurve im Data-Array (kann anders sortiert sein) und entfernen dieser
        for (var data_index in data_array) {
            if (data_array[data_index].label === legend_name){
                if (data_array[data_index]['delete_callback']){
                    data_array[data_index]['delete_callback'](legend_name);     // deregistrieren der Spalte beim Aufrufer wenn callback hinterlegt
                }
                data_array.splice(data_index, 1);                               // Entfernen des Elements aus Data_Array
                plot_diagram(unique_id, plot_area_id, caption, data_array, options);    // Neuzeichnen des Diagramm
            }
        }
    };


    /**
     * Translate key into string according to options[:locale]
     * @param key
     */
    function locale_translate(key){
        if (get_translations()[key]){
            if (get_translations()[key][options.plot_diagram.locale]){
                return get_translations()[key][options.plot_diagram.locale];
            } else {
                if (get_translations()[key]['en'])
                    return get_translations()[key]['en'];
                else
                    return 'No default translation (en) available for key "'+key+'"';
            }
        } else {
            return 'No translation available for key "'+key+'"';
        }
    }

    function get_translations() {
        return {
            'diagram_y_axis_show_name': {
                'en': 'Show y-axis',
                'de': 'y-Achse(n) anzeigen'
            },
            'diagram_y_axis_show_hint': {
                'en': 'Show all scale values of y-axis',
                'de': 'Skalenwerte der Y-Achse(n) anzeigen'
            },
            'diagram_y_axis_hide_name': {
                'en': 'Hide y-axis',
                'de': 'y-Achse(n) ausblenden'
            },
            'diagram_y_axis_hide_hint': {
                'en': 'Hide scale values of y-axis',
                'de': 'Skalenwerte der Y-Achse(n) ausblenden'
            },
            'diagram_all_on_name': {
                'en': 'All column curves with one scale for y-axis',
                'de': 'Alle Spalten-Kurven in einer y-Achse darstellen'
            },
            'diagram_all_on_hint': {
                'en': 'Show all column curves with only one scale for y-axis',
                'de': 'Alle Spalten-Kurven in einer y-Achse darstellen'
            },
            'diagram_all_off_name': {
                'en': 'Own y-axis per curve (100% scale)',
                'de': 'Eigene y-Achse je Kurve (100% Wertebereich)'
            },
            'diagram_all_off_hint': {
                'en': 'Own y-axis for every column curve (each with 100% scale)',
                'de': 'Eigene y-Achse je Spalten-Kurve (jede Kurve hat 100% des Wertebereich)'
            },
            'diagram_stack_name': {
                'en': 'Stack single charts',
                'de': 'Stapeln der einzelnen Kurven'
            },
            'diagram_stack_hint': {
                'en': 'Shows values for single charts and sum simultaneously',
                'de': 'Erlaubt gleichzeitige Sicht auf Einzelwerte und Summe'
            },
            'diagram_unstack_name': {
                'en': 'Unstack single charts',
                'de': 'Entstapeln der einzelnen Kurven'
            },
            'diagram_unstack_hint': {
                'en': 'Each chart shows own values in y-axis',
                'de': 'Jede Kurve zeigt ihre eigenen Werte auf Y-Achse'
            },
            'diagram_hide_points_hint': {
                'en': "Don't show single values as circle on chart",
                'de': 'Einzelwerte nicht als Kreis auf der Kurve anzeigen'
            },
            'diagram_show_points_hint': {
                'en': 'Show single values as circle on chart',
                'de': 'Einzelwerte als Kreis auf der Kurve anzeigen'
            },
            'diagram_hide_points_name': {
                'en': "Don't show single values as circle",
                'de': 'Einzelwerte nicht als Kreis zeigen'
            },
            'diagram_show_points_name': {
                'en': 'Show single values as circle',
                'de': 'Einzelwerte als Kreis zeigen'
            },
            'diagram_remove_chart': {
                'en': 'Remove this chart from diagram',
                'de': 'Diese Kurve aus dem Diagramm entfernen'
            },
            'diagram_remove_chart_confirm': {
                'en': 'Remove chart',
                'de': 'Entfernen der Kurve'
            },
            'diagram_save_to_image_name': {
                'en': 'Save chart to image',
                'de': 'Speichern als Bild'
            },
            'diagram_save_to_image_hint': {
                'en': 'Save complete chart to image',
                'de': 'Speichern des ganzen Diagrammes als Bild'
            }
        };
    }

} // plot_diagram


function resize_plot_diagrams(){
    jQuery('.plot_diagram').each(function(index, element) {
            var Container = jQuery(element);
            Container.data('plot_diagram').registerLegend();
        }
    );
}

// Entfernen einer konkreten Kurve
function delete_single_plot_chart(plot_area_id, index){
    jQuery('#'+plot_area_id).data('plot_diagram').delete_single_chart(index);   // Weitergabe Event an Methode des plot_diagram-Objektes
    return false;
}




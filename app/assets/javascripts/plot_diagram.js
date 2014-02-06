// Ermitteln der Dimensionen aller Zellen der Zeile und Abgleich gegen bisherige Werte der Spalte
// Parameter: Zelle des data-Array
//            Zelle des metadata-Array
//            Column-Definition                                                // Zeichnen eines Diagrammes aus den übergebenen Datentupeln
// Parameter:
// Unique-ID fuer Bildung der Canvas-ID
// DOM-ID of DIV for plotting
// Kopfzeile
// Daten-Array
// multiple_y_axes  bool
// show_y_axes      bool
// x_axis_time      bool    Ist X-Achse ein Zeitstempel oder Nummer
function plot_diagram(unique_id, plot_area_id, caption, data_array, multiple_y_axes, show_y_axes, x_axis_time, locale) {
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

    var context_menu_id = "menu_"+canvas_id;
    var menu = jQuery("<div class='contextMenu' id='"+context_menu_id+"' style='display:none;'>").insertAfter('#'+canvas_id);
    var ul   = jQuery("<ul></ul>").appendTo(menu);
    jQuery("<div id='header_"+context_menu_id+"' style='padding: 3px; background-color:lightgray;' align='center'>Diagram</div>").appendTo(ul);
    var bindings = {};

    function context_menu_entry(name, icon_class, label, hint, click_action ){
        jQuery("<li id='"+context_menu_id+"_"+name+"' title='"+hint+"'><span class='"+icon_class+"' style='float:left'></span><span id='"+context_menu_id+"_"+name+"_label'>"+label+"</span></li>").appendTo(ul);
        bindings[context_menu_id+"_"+name] = click_action;
    }

    context_menu_entry(
        'y_axis',
        "ui-icon ui-icon-zoomin",
        show_y_axes==true ? locale_translate('diagram_y_axis_hide_name') : locale_translate('diagram_y_axis_show_name'),
        show_y_axes==true ? locale_translate('diagram_y_axis_hide_hint') : locale_translate('diagram_y_axis_show_hint'),
        function(t){
            plot_area.html(""); // Altes Diagramm entfernen
            plot_diagram(unique_id, plot_area_id, caption, data_array, multiple_y_axes, (show_y_axes==true ? false : true), x_axis_time);
        }
    );

    context_menu_entry(
        'all_in_one',
        "ui-icon ui-icon-zoomin",
        multiple_y_axes==true ? locale_translate('diagram_all_on_name') : locale_translate('diagram_all_off_name'),
        multiple_y_axes==true ? locale_translate('diagram_all_on_hint') : locale_translate('diagram_all_off_hint'),
        function(t){
            plot_area.html(""); // Altes Diagramm entfernen
            plot_diagram(unique_id, plot_area_id, caption, data_array, (multiple_y_axes==true ? false : true), show_y_axes, x_axis_time);
        }
    );

    jQuery('#'+canvas_id).contextMenu(context_menu_id, {
        menuStyle: {  width: '330px' },
        bindings:   bindings,
        onContextMenu : function(event, menu)                                   // dynamisches Anpassen des Context-Menü
        {
            var cell = $(event.target);
            return true;
        }
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
    jQuery('#'+canvas_id+" .legend").find("table").addClass('legend_table');
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


    /**
     * Translate key into string according to options[:locale]
     * @param key
     */
    function locale_translate(key){
        if (get_translations()[key]){
            if (get_translations()[key][locale]){
                return get_translations()[key][locale];
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
            }
        }
    }


} // plot_diagram

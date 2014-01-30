/**
* (c) 2014 Peter Ramm
*
* Personal extension for SlickGrid v2.1 (Michael Leibman)
*
*/


/**
 * Creates a new instance of the grid.
 * @class SlickGridExtended
 * @constructor
 * @param {Node}              container_id  ID of DOM-Container node to create the grid in. (without jQuery-Selector prefix)
 * @param {Array}             data          An array of objects for databinding.
 * @param {Array}             columns       An array of column definitions.
 * @param {Object}            options       Grid options.
 * @param {Array}             additional_context_menu Array with additional context menu entries as object
 *                             { label: "Menu-Label", hint: "MouseOver-Hint", ui_icon: "ui-icon-image", action:  function(t){ ActionName } }
 **/
function SlickGridExtended(container_id, data, columns, options, additional_context_menu){
    var gridContainer = jQuery('#'+container_id);                                      // Puffern des jQuery-Objektes

    columns = calculate_header_column_width(columns);                           // columns um Weiten-Info der Header erweitern

    var columnFilters = {};
    var dataView = new Slick.Data.DataView();
    dataView.setItems(data);
    options["searchFilter"] = slickgrid_filter_item_row;                        // merken filter-Funktion für Aktivierung über Menü
    //dataView.setFilter(slickgrid_filter_item_row);

    options['headerHeight']  = 1;                                               // Default, der später nach Notwendigkeit größer gesetzt wird
    options['rowHeight']     = 1;                                               // Default, der später nach Notwendigkeit größer gesetzt wird

    options['plotting']      = false;                                           // Soll Diagramm zeichenbar sein: Default=false wenn nicht eine Spalte als x-Achse deklariert ist
    for (var col_index in columns) {
        column = columns[col_index];
        if (options['plotting'] && (column['plot_master'] || column['plot_master_time']))
            alert('Es kann nur eine Spalte einer Tabelle Plot-Master für X-Achse sein');
        if (column['plot_master'] || column['plot_master_time'])
            options['plotting'] = true;
    }

    var grid = new Slick.Grid(gridContainer, dataView, columns, options);

    gridContainer
        .data('slickgrid', grid)                                                // speichern Link auf JS-Objekt für Zugriff auf slickgrid-Objekt über DOM
        .css('margin-top', '2px')
        .css('margin-bottom', '2px')
    ;

    // Grid durch Schieber am unteren Ende horitontal resizable gestalten
    gridContainer.resizable({
        stop: function( event, ui ) {
            ui.element
                .css('width', '')                                         // durch Resize gesetzte feste Weite wieder entfernen, da sonst Weiterleitung resize des Parents nicht wirkt
                .css('top', '')
                .css('left', '')
            ;
            finish_vertical_resize(ui.element);                          // Sicherstellen, dass Höhe des Containers nicht größer als Höhe des Grids mit allen Zeilen sichtbar
        }
    })
    ;
    gridContainer.find(".ui-resizable-e").remove();                            // Entfernen des rechten resizes-Cursors
    gridContainer.find(".ui-resizable-se").remove();                           // Entfernen des rechten unteren resize-Cursors

    if (!options['plot_area']){
        var plot_area = 'plot_area_'+Math.floor(Math.random()*1000000);                      // Zufällige numerische ID
        options['plot_area'] = '#'+plot_area
        gridContainer.after('<div id="'+plot_area+'"></div>');
    }

    initialize_slickgrid();                                                     // einmaliges Initialisieren des SlickGrid

    calculate_current_grid_column_widths(gridContainer, 'setup_slickgrid'); // erstmalige Berechnung der Größen

    adjust_real_grid_height(gridContainer);                                     // Anpassen der Höhe des Grid an maximale Höhe des Inhaltes

    build_slickgrid_context_menu(container_id, additional_context_menu);           // Aufbau Context-Menu fuer Liste


    // ###################### Ende Constructor-Code #######################




    // initialer Aufbau des SlickGrid-Objektes
    function initialize_slickgrid(){
        grid.onSort.subscribe(function(e, args) {
            var col = args.sortCol;
            var sort_smaller = function(value1, value2){return value1<value2;};     // Default-Sortier-Funktion für String

            if (col['sort_type'] == "float"){
                sort_smaller = function(value1, value2){
                    return parseFloatLocale(value1) < parseFloatLocale(value2);
                }
            }

            if (col['sort_type'] == "date" && session_locale == 'de'){              // englisches Date lässt sich als String sortieren
                sort_smaller = function(value1, value2){
                    function convert(value){
                        var tag_zeit = value.split(" ");
                        var dat = tag_zeit[0].split(".")
                        return dat[2]+dat[1]+dat[0]+(tag_zeit[1] ? tag_zeit[1] : "");
                    }
                    return convert(value1) < convert(value2);
                }
            }

            // Bubblesort-Funktion zur Erhaltung der vorherigen Sortierung innerhalb gleicher Werte als Ersatz für Array.sort
            function swap(z,a,b) {
                temp=z[a];
                z[a]=z[b];
                z[b]=temp;
            }

            var field = col.field;
            for(var m=dataView.getItems().length-1; m>0; m--){
                for(var n=0; n<m; n++){
                    if (args.sortAsc){
                        if (sort_smaller(dataView.getItems()[n+1][field], dataView.getItems()[n][field]))
                            swap(dataView.getItems(),n,n+1);
                    } else {
                        if (sort_smaller(dataView.getItems()[n][field], dataView.getItems()[n+1][field]))
                            swap(dataView.getItems(),n,n+1);
                    }
                }
            }

            //dataView.idxById = {};
            //dataView.updateIdxById();
            dataView.refresh();                                                     // DataView mit sortiertem Inhalt synchr.


            grid.invalidate();
            grid.render();
        });

        grid.onScroll.subscribe(function(){
            if (slickgrid_render_needed ==1){
                slickgrid_render_needed = 0;
                calculate_current_grid_column_widths(jQuery(this.getCanvasNode()).parents(".slickgrid_top"), 'onScroll');
            }
        });

        grid.onHeaderCellRendered.subscribe(function(node, column){
            jQuery(column.node).css('height', column.grid.getOptions()['headerHeight']);        // Höhe der Header-Zeile setzen nach dem initialen setzen der Höhe durch slickgrid
        });

        grid.onColumnsResized.subscribe(function(){
            processColumnsResized(this);
        });

        dataView.onRowCountChanged.subscribe(function (e, args) {                   // benötigt für Search-Filter
            grid.updateRowCount();
            grid.render();
        });

        dataView.onRowsChanged.subscribe(function (e, args) {                       // benötigt für Search-Filter
            grid.invalidateRows(args.rows);
            grid.render();
        });


        $(grid.getHeaderRow()).delegate(":input", "change keyup", function (e) {
            var columnId = $(this).data("columnId");
            if (columnId != null) {
                columnFilters[columnId] = $.trim($(this).val());
                dataView.refresh();
            }
        });


        grid.onHeaderRowCellRendered.subscribe(function(e, args) {                  // Zeichnen der Zeile mit Filter-Eingaben

            function input_hint(column_id){                                         // Ermitteln spezifischer Hints für numerisch oder nicht
                if (grid.getColumns()[grid.getColumnIndex(column_id)].sort_type == "float" )
                    return locale_translate("slickgrid_filter_hint_numeric");
                else
                    return locale_translate("slickgrid_filter_hint_not_numeric");
            }

            $(args.node).empty();
            $("<input type='text' style='font-size: 11.5px; width: 100%;' title='"+input_hint(args.column.id)+"'>")
                .data("columnId", args.column.id)
                .val(columnFilters[args.column.id])
                .appendTo(args.node);
        });

        grid.onDblClick.subscribe(function(e, args){
            show_full_cell_content(jQuery(grid.getCellNode(args['row'], args['cell'])).children().text());  // Anzeige des Zell-Inhaltes
        });

        // Caption setzen
        if (options['caption'] && options['caption'] != ""){
            var caption = jQuery("<div id='caption_"+container_id.replace(/#/, "")+"' class='slick-caption'></div>").insertBefore(container_id);
            caption.html(options['caption'])
        }
    }   // initialize_slickgrid


    // Filtern einer Zeile des Grids gegen aktuelle Filter
    function slickgrid_filter_item_row(item) {
        for (var columnId in columnFilters) {
            if (columnId !== undefined && columnFilters[columnId] !== "") {
                var c = grid.getColumns()[grid.getColumnIndex(columnId)];
                if (c.sort_type == "float" &&  item[c.field] != columnFilters[columnId]) {
                    return false;
                }
                if (c.sort_type != "float" &&  (item[c.field].toUpperCase().match(columnFilters[columnId].toUpperCase())) == null ) {
                    return false;
                }
            }
        }
        return true;
    }

    // Ermittlung Spaltenbreite der Header auf Basis der konketen Inhalte
    function calculate_header_column_width(columns){
        // DIVs für Test der resultierenden Breite von Zellen für slickGrid
        var test_header_outer      = jQuery('<div class="slick_header_column ui-widget-header" style="visibility:hidden; position: absolute; z-index: -1; padding: 0; margin: 0;"><nobr><div id="test_header" style="width: 1px; overflow: hidden;"></div></nobr></div>');
        gridContainer.after(test_header_outer);                             // Einbinden in DOM-Baum
        var test_header         = test_header_outer.find('#test_header');       // Objekt zum Test der realen string-Breite

        // TABLE für umgebrochene Zeichenbreite
        var test_header_wrap_outer = jQuery('<table style="visibility:hidden; position:absolute; width:1;"><tr><td class="slick_header_column ui-widget-header" style="padding: 0; margin: 0;"><div id="test_header_wrap"></div></td></tr></table>');
        gridContainer.after(test_header_wrap_outer);
        var test_header_wrap  = test_header_wrap_outer.find('#test_header_wrap'); // Objekt zum Test der realen string-Breite für td

      //  var test_header_wrap  = jQuery('#test_header_wrap');

        var column;                                                             // aktuell betrachtete Spalte

        // Ermittlung max. Zeichenbreite ohne Umbrüche
        for (var col_index in columns){
            column = columns[col_index]

            test_header.html(column['name']);                                   // Test-Zelle mit zu messendem Inhalt belegen
            column['header_nowrap_width']  = test_header.prop("scrollWidth");   // genutzt für Test auf Umbruch des Headers, dann muss Höhe der Header-Zeile angepasst werden

            test_header_wrap.html(column['name']);
            column['max_wrap_width']      = test_header_wrap.width();

            column['max_nowrap_width']    = column['max_wrap_width']            // Normbreite der Spalte mit Mindestbreite des Headers initialisieren (lieber Header umbrechen als Zeilen einer anderen Spalte)
        }

        // Entfernen der DIVs fuer Breitenermittlung aus dem DOM-Baum
        test_header_outer.remove();
        test_header_wrap_outer.remove();
        return columns;
    }



// Aufbau context-Menu für slickgrid, Parameter: DOM-ID, Array mit Entry-Hashes
    var last_slickgrid_contexmenu_col_header=null;                                  // globale Variable mit jQuery-Objekt des Spalten-Header der Spalte, in der Context-Menu zuletzt gerufen wurd
    var last_slickgrid_contexmenu_column_name='';                                   // globale Variable mit Spalten-Name der Spalte, in der Context-Menu zuletzt gerufen wurd
    var last_slickgrid_contexmenu_field_content='';                                 // globale Variable mit Inhalt des Feldes auf dem Context-Menu aufgerufen wurde
//    this.build_slickgrid_context_menu = function(table_id,  menu_entries){
    function build_slickgrid_context_menu(table_id,  menu_entries){
        var grid_table = jQuery('#'+table_id);
        var grid = grid_table.data('slickgrid');
        var options = grid.getOptions();
        var context_menu_id = "menu_"+table_id;
        var menu = jQuery("<div class='contextMenu' id='"+context_menu_id+"' style='display:none;'>").insertAfter('#'+table_id);
        var ul   = jQuery("<ul></ul>").appendTo(menu);
        jQuery("<div id='header_"+context_menu_id+"' style='padding: 3px;' align='center'>Header</div>").appendTo(ul);
        var bindings = {};

        function menu_entry(name, icon_class, click_action, label, hint){
            if (!label)
                label = locale_translate("slickgrid_context_menu_"+name);
            if (!hint)
                hint = locale_translate("slickgrid_context_menu_"+name+"_hint");
            jQuery("<li id='"+context_menu_id+"_"+name+"' title='"+hint+"'><span class='"+icon_class+"' style='float:left'></span><span id='"+context_menu_id+"_"+name+"_label'>"+label+"</span></li>").appendTo(ul);
            bindings[context_menu_id+"_"+name] = click_action;

        }

        menu_entry("sort_column",       "ui-icon ui-icon-carat-2-n-s",      function(t){ last_slickgrid_contexmenu_col_header.click();} );                  // Menu-Eintrag Sortieren
        menu_entry("search_filter",     "ui-icon ui-icon-zoomin",           function(t){ switch_slickgrid_filter_row(grid, grid_table);} );                 // Menu-Eintrag Filter einblenden / verstecken
        menu_entry("export_csv",        "ui-icon ui-icon-document",         function(t){ grid2CSV(table_id);} );                                            // Menu-Eintrag Export CSV
        menu_entry("column_sum",        "ui-icon ui-icon-document",         function(t){ show_column_stats(grid, last_slickgrid_contexmenu_column_name);} );  // Menu-Eintrag Spaltensumme
        menu_entry("field_content",     "ui-icon ui-icon-arrow-4-diag",     function(t){ show_full_cell_content(last_slickgrid_contexmenu_field_content);} ); // Menu-Eintrag Feld-Inhalt
        menu_entry("line_height_single","ui-icon ui-icon-arrow-2-n-s",      function(t){ options['line_height_single'] = !options['line_height_single']; calculate_current_grid_column_widths(grid_table, "context menu line_height_single");} );


        if (options['plotting']){
            // Menu-Eintrag Spalte in Diagramm
            menu_entry("plot_column",     "ui-icon ui-icon-image",     function(t){ plot_slickgrid_diagram(table_id, options['plot_area'], options['caption'], last_slickgrid_contexmenu_column_name, options['multiple_y_axes'], options['show_y_axes']);} );
            // Menu-Eintrag Alle entfernen aus Diagramm
            menu_entry("remove_all_from_diagram", "ui-icon ui-icon-trash",         function(t){
                    var columns = grid.getColumns();
                    for (var col_index in columns){
                        columns[col_index]['plottable'] = 0;
                    }
                    plot_slickgrid_diagram(table_id, options['plot_area'], options['caption'], null);  // Diagramm neu zeichnen
                }
            );
        }

        for (entry_index in menu_entries){
            menu_entry(entry_index, "ui-icon "+menu_entries[entry_index]['ui_icon'], menu_entries[entry_index]['action'], menu_entries[entry_index]['label'], menu_entries[entry_index]['hint']);
        }

        grid_table.contextMenu(context_menu_id, {
            menuStyle: {  width: '330px' },
            bindings:   bindings,
            onContextMenu : function(event, menu)                                   // dynamisches Anpassen des Context-Menü
            {
                var cell = $(event.target);
                last_slickgrid_contexmenu_col_header = null;                        // Initialisierung, um nachfolgend Treffer zu testen

                if (cell.parents(".slickgrid_header_"+table_id).length > 0){        // Mouse-Event fand in Unterstruktur des Spalten-Headers statt
                    cell = cell.parents(".slickgrid_header_"+table_id);             // Zeiger auf Spaltenheader stellen
                }
                if (cell.hasClass("slickgrid_header_"+table_id)){                   // Mouse-Event fand direkt im Spalten-Header oder innerhalb statt
                    last_slickgrid_contexmenu_col_header = cell;
                    last_slickgrid_contexmenu_column_name = cell.data('column')['field']
                }
                if (cell.parents(".slick-cell").length > 0){                        // Mouse-Event fand in Unterstruktur der Zelle statt
                    cell = cell.parents(".slick-cell");                             // Zeiger auf äußerstes DIV der Zelle stellen
                }
                if (cell.hasClass("slick-cell")){                                   // Mouse-Event fand in äußerstem DIV der Zelle oder innerhalb statt
                    var slick_header = grid_table.find('.slick-header-columns');
                    cell = cell.find(".slick-inner-cell");                          // Inneren DIV mit Spalten-Info suchen
                    last_slickgrid_contexmenu_col_header = slick_header.children('[id$=\"'+cell.attr('column')+'\"]');  // merken der Header-Spalte des mouse-Events;
                    last_slickgrid_contexmenu_column_name = cell.attr('column');
                    last_slickgrid_contexmenu_field_content = cell.text();
                }

                if (last_slickgrid_contexmenu_col_header) {                         // konkrete Spalte ist bekannt
                    var column = grid.getColumns()[grid.getColumnIndex(last_slickgrid_contexmenu_column_name)];
                    jQuery('#header_'+context_menu_id)
                        .html('Column: <b>'+last_slickgrid_contexmenu_col_header.html()+'</b>')
                        .css('background-color','lightgray');

                    jQuery("#"+context_menu_id+"_plot_column_label").html(locale_translate(column['plottable'] ? "slickgrid_context_menu_switch_col_from_diagram" : "slickgrid_context_menu_switch_col_into_diagram"));
                    jQuery("#"+context_menu_id+"_line_height_single_label").html(locale_translate(options["line_height_single"] ? "slickgrid_context_menu_line_height_full" : "slickgrid_context_menu_line_height_single"));
                } else {
                    jQuery('#header_'+context_menu_id)
                        .html('Column/cell not exactly hit! Please retry.')
                        .css('background-color','red');
                }
                jQuery("#"+context_menu_id+"_search_filter_label").html(locale_translate(grid.getOptions()["showHeaderRow"] ? "slickgrid_context_menu_hide_filter" : "slickgrid_context_menu_show_filter"));
                return true;
            }
        });
    }


}
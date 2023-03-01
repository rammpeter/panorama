"use strict";

/**
 * @name SlickGridExtended
 * @version 1.0
 * @requires jQuery v1.10+, slick.grid, flot
 * @author Peter Ramm
 * @license MIT License - http://www.opensource.org/licenses/mit-license.php
 *
 * (c) 2014 Peter Ramm
 * https://github.com/rammpeter/Panorama/blob/master/app/assets/javascripts/slickgrid_extended.js
 *
 * Personal extension for SlickGrid v2.4 (originated by Michael Leibman)
 * Based on version 2.4.3 from https://github.com/6pac/SlickGrid
 *
*
*/

/**
 * Helper function to initialize
 *
 * @param {string}      container_id    element-id for diagram container
 * @param {Array}       data            An array of objects for databinding.
 * @param {Array}       columns         An array of column definitions.
 * @param {Object}      options         Grid options.
 * @param {Array}       additional_context_menu Array with additional context menu entries as object
 * @return {SlickGridExtended} object
 */
function createSlickGridExtended(container_id, data, columns, options, additional_context_menu){
    var sle = new SlickGridExtended(container_id, options);
    sle.initSlickGridExtended(container_id, data, columns, options, additional_context_menu);
    sle.grid.getColumns().forEach(function(column){
        if (!column.hidden)
            batch_calc_cell_dimensions(sle, column, 0, 100);                    // Calculate width for the first 100 records for all columns
    });
    sle.calculate_current_grid_column_widths('createSlickGridExtended');        // Sicherstellen, dass mindestens ein zweites Mal diese Funktion durchlaufen wird und Scrollbars real berücksichtigt werden
    setTimeout(async_calc_all_cell_dimensions, 0, sle, 0, 0);                   // Asynchrone Berechnung der noch nicht vermessenen Zellen für Kalkulation der Weite
    return sle;
}

/**
 * Creates a new instance of the grid.
 * @class SlickGridExtended
 * @constructor
 * @param {Node}              container_id  ID of DOM-Container node to create the grid in. (without jQuery-Selector prefix).  This Container should not have additional styles (margin, padding, etc.)
 * @param {Object}      options         Grid options.
 **/
function SlickGridExtended(container_id, options){
    // ###################### Begin Constructor-Code #######################
    var thiz = this;                                                            // Persistieren Objekt-Zeiger über Constructor hinaus, da this in privaten Methoden nicht mehr gültig ist

    // Ermitteln der Breite eines Scrollbars (nur einmal je Session wirklich ausführen, sonst gecachten wert liefern)
    var scrollbarWidth_internal_cache   = null;   // Ergebnis von scrollbarWidth zur Wiederverwendung
    var js_test_cell                    = null;                                 // Objekt zum Test der realen string-Breite für td, wird bei erstem Zugriff initialisiert
    var js_test_cell_wrap               = null;                                 // Objekt zum Test der realen string-Breite für td, wird bei erstem Zugriff initialisiert
    var js_test_cell_heigth             = null;                                 // Objekt zum Test der realen Höhe einer Zeile
    var js_test_cell_header             = null;
    var columnFilters                   = {};                                   // aktuelle Filter-Kriterien der Daten
    this.grid                           = null;                                 // Referenz auf SlickGrid-Objekt, belegt erst in initSlickGridExtended
    this.data_items                     = null;
    var last_slickgrid_contexmenu_col_header    = null;                         // globale Variable mit jQuery-Objekt des Spalten-Header der Spalte, in der Context-Menu zuletzt gerufen wurd
    var last_slickgrid_contexmenu_column_name   = '';                           // globale Variable mit Spalten-Name der Spalte, in der Context-Menu zuletzt gerufen wurd
    var last_slickgrid_contexmenu_field_content = '';                           // globale Variable mit Inhalt des Feldes auf dem Context-Menu aufgerufen wurde
    var pinned                          = false;                                // is table pinned ?

    this.gridContainer = jQuery('#'+container_id);                              // Puffern des jQuery-Objektes
    this.gridContainer.addClass('slickgrid_top');                               // css-Klasse setzen zur Wiedererkennung
    jQuery(window).resize(function(){ resize_handler();});                      // Registrieren des Resize-Event Handlers

    // ###################### Ende Constructor-Code #######################

    /**
     * Helper zur Initialisierung des Objektes
     * @param container_id              ID of DOM-Container node to create the grid in. (without jQuery-Selector prefix).  This Container should not have additional styles (margin, padding, etc.)
     * @param data                      An array of objects for databinding.
     * @param columns                   An array of column definitions.
     * @param options                   Grid options.
     * @param additional_context_menu   additional_context_menu Array with additional context menu entries as object
     *                             { label: "Menu-Label", hint: "MouseOver-Hint", ui_icon: "cui-x", action:  function(t){ ActionName } }
     */
    this.initSlickGridExtended = function(container_id, data, columns, options, additional_context_menu){
        var col_index;
        var column;
        this.all_columns = columns;                                             // Column-Deklaration in der Form wie dem SlickGrid übergeben inkl. hidden columns

        var viewable_columns = [];
        for (col_index in columns) {
            column = columns[col_index];
            if (!column['hidden'])                                              // nur sichtbare Spalten weiter verwenden
                viewable_columns.push(column);
        }

        init_test_cells();                                                      // hidden DIV-Elemente fuer Groessentest aufbauen
        init_columns_and_calculate_header_column_width(viewable_columns, container_id);  // columns um Defaults und Weiten-Info der Header erweitern
        init_data(data, columns);                                               // data im fortlaufende id erweitern, auch für hidden columns
        init_options(options);                                                  // Options um Defaults erweitern

        this.data_items = data;                                                 // direkt access to data structure
        var dataView = new Slick.Data.DataView();
        dataView.setItems(data);
        options["searchFilter"] = slickgrid_filter_item_row;                    // merken filter-Funktion für Aktivierung über Menü
        //dataView.setFilter(slickgrid_filter_item_row);

        if (options['maxHeight'] && !jQuery.isNumeric(options['maxHeight'])) {  // Expression set instead of numeric value for pixel
            options['maxHeight'] = eval(options['maxHeight']);                  // execute expression to get height in px
        }
        options['maxHeight'] = Math.round(options['maxHeight']);                // Sicherstellen Ganzzahligkeit

//        options['headerHeight']  = 1;                                           // Default, der später nach Notwendigkeit größer gesetzt wird
        options['rowHeight']     = 1;                                           // Default, der später nach Notwendigkeit größer gesetzt wird

        options['plotting']      = false;                                       // Soll Diagramm zeichenbar sein: Default=false wenn nicht eine Spalte als x-Achse deklariert ist
        for (col_index in viewable_columns) {
            column = viewable_columns[col_index];
            if (options['plotting'] && (column['plot_master'] || column['plot_master_time']))
                alert('Only one column of table can be plot-master for x-axis!');
            if (column['plot_master'] || column['plot_master_time'])
                options['plotting'] = true;

            if (column['show_pct_hint'] || column['show_pct_background']){
                var column_sum = 0;
                for (var row_index in data){
                    column_sum += this.parseFloatLocale(data[row_index]['col'+col_index]);  // Kumulieren der Spaltensumme
                }
                column['column_sum'] = column_sum;
            }
        }

        // caution: next DIVs are created in reverse order after gridContainer: result order is: plot_area_id, direct_update_area, update_area
        if (options['update_area']){
            this.gridContainer.after('<div id="' + options['update_area'] + '"></div>');
        }

        if (options['direct_update_area']){
            this.gridContainer.after('<div id="' + options['direct_update_area'] + '"></div>');
        }

        if (options['plotting'] && !options['plot_area_id']){                   // DIV fuer Anzeige des Diagramms fehlt noch
            options['plot_area_id'] = 'plot_area_' + container_id;              // Generierte ID des DIVs fuer Diagramm-Anzeige
            this.gridContainer.after('<div id="' + options['plot_area_id'] + '"></div>');
        }

        this.grid = new Slick.Grid(this.gridContainer, dataView, viewable_columns, options);

        this.gridContainer
            .data('slickgrid', this.grid)                                       // speichern Link auf JS-Objekt für Zugriff auf slickgrid-Objekt über DOM
            .data('slickgridextended', this)                                    // speichern Link auf JS-Objekt für Zugriff auf slickgrid-Objekt über DOM
            .css('margin-top', '2px')
            .css('margin-bottom', '2px')
            .addClass('slick-shadow')
        ;

        // Grid durch Schieber am unteren Ende horizontal resizable gestalten
        this.gridContainer.resizable({
            stop: function( event, ui ) {
                ui.element
                    .css('width', '')                                           // durch Resize gesetzte feste Weite wieder entfernen, da sonst Weiterleitung resize des Parents nicht wirkt
                    .css('top', '')
                    .css('left', '')
                ;
                finish_vertical_resize();                                       // Sicherstellen, dass Höhe des Containers nicht größer als Höhe des Grids mit allen Zeilen sichtbar
            }
        })
        ;
        this.gridContainer.find(".ui-resizable-e").remove();                    // Entfernen des rechten resizes-Cursors
        this.gridContainer.find(".ui-resizable-se").remove();                   // Entfernen des rechten unteren resize-Cursors

        initialize_slickgrid(this.grid);                                        // einmaliges Initialisieren des SlickGrid

        build_slickgrid_context_menu(container_id, additional_context_menu);    // Aufbau Context-Menu fuer Liste

    };


    /**
     * initialer Aufbau des SlickGrid-Objektes
     *
     * @param {Object} grid  SlickGrid-object
     */
    function initialize_slickgrid(grid){
        var dataView = grid.getData();

        grid.onSort.subscribe(function(e, args) {
            var col = args.sortCol;
            var field = col.field;

            function convert_german_date(value){                                // de-Datum in sortierbaren string konvetieren
                var tag_zeit = value.split(" ");
                var dat = tag_zeit[0].split(".");
                return dat[2]+dat[1]+dat[0]+(tag_zeit[1] ? tag_zeit[1] : "");
            }

            // Quicksort-Funktion zum schnellen sortieren
            function quickSort(){

                var sortFunc = function(a,b){                                       // Default für String
                    if (a[field] < b[field])
                        return -1;
                    if (a[field] > b[field])
                        return 1;
                    if (a[field] === b[field])
                        return 0;
                };

                if (col['sort_type'] === "float") {
                    sortFunc  = function(a, b) {
                        return thiz.parseFloatLocale(a[field]) - thiz.parseFloatLocale(b[field]);
                    }
                } else if (col['sort_type'] === "date" && options['locale'] === 'de'){
                    sortFunc  = function(a, b){
                        var fa = convert_german_date(a[field]);
                        var fb = convert_german_date(b[field]);
                        if (fa < fb)
                            return -1;
                        if (fa > fb)
                            return 1;
                        if (fa === fb)
                            return 0;
                    }
                }
                dataView.getItems().sort(sortFunc);
            }


            // Bubblesort-Funktion zur Erhaltung der vorherigen Sortierung innerhalb gleicher Werte als Ersatz für Array.sort
            function bubbleSort(){
                var data_array = dataView.getItems();

                var sort_smaller = function(value1, value2){return value1<value2;};     // Default-Sortier-Funktion für String

                if (col['sort_type'] === "float"){
                    sort_smaller = function(value1, value2){
                        return thiz.parseFloatLocale(value1) < thiz.parseFloatLocale(value2);
                    }
                }

                if (col['sort_type'] === "date" && options['locale'] === 'de'){              // englisches Date lässt sich als String sortieren
                    sort_smaller = function(value1, value2){
                        return convert_german_date(value1) < convert_german_date(value2);
                    }
                }

                function swap(a,b) {
                    var temp=data_array[a];
                    data_array[a]=data_array[b];
                    data_array[b]=temp;
                }

                for(var m=data_array.length-1; m>0; m--){
                    for(var n=0; n<m; n++){
                        if (sort_smaller(data_array[n+1][field], data_array[n][field]))
                            swap(n,n+1);
                    }
                }
            }
            if (grid.getOptions()['sort_method'] === 'QuickSort'){
                quickSort();
            } else if (grid.getOptions()['sort_method'] === 'BubbleSort'){
                bubbleSort();
            } else {
                alert('Option "sort_method" with unsuported value "'+grid.getOptions()['sort_type']+'"');
            }

            if (!args.sortAsc)
                dataView.getItems().reverse();
            dataView.refresh();                                                     // DataView mit sortiertem Inhalt synchr.
            grid.invalidate();
            grid.render();
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
                if (grid.getColumns()[grid.getColumnIndex(column_id)].sort_type === "float" )
                    return locale_translate("slickgrid_filter_hint_numeric");
                else
                    return locale_translate("slickgrid_filter_hint_not_numeric");
            }

            $(args.node).empty();
            $("<input type='text' style='font-size: 12px; width: 100%;' title='"+input_hint(args.column.id)+"'>")
                .data("columnId", args.column.id)
                .val(columnFilters[args.column.id])
                .appendTo(args.node);
        });

        grid.onDblClick.subscribe(function(e, args){
            show_full_cell_content(jQuery(grid.getCellNode(args['row'], args['cell'])).children().html());  // Anzeige des Zell-Inhaltes
        });

        // set caption and additional menu actions
        if (options['caption'] && options['caption'] !== ""){
            var caption = jQuery("<div id='caption_"+container_id+"' class='slick-caption slick-shadow'></div>").insertBefore('#'+container_id);

            var caption_left_box  = jQuery("<span class='slick_header_left_box'></span>");
            var caption_right_box = jQuery("<span class='slick_header_right_box'></span>");
            caption.append(caption_left_box);
            caption.append('<span class="slick_header_middle_box">'+options['caption']+'</span>');                                 // Add header text itself
            caption.append(caption_right_box);

            // add default command menu entries
            if (!options['command_menu_entries']){
                options['command_menu_entries'] = [];
            }

            options['command_menu_entries'].reverse();                          // allow pushed element to be at first position
            options['command_menu_entries'].push({
                name:                   'toggle_search_filter',
                caption:                locale_translate("slickgrid_context_menu_search_filter"),
                hint:                   locale_translate("slickgrid_context_menu_search_filter_hint"),
                icon_class: 'cui-magnifying-glass',
                show_icon_in_caption:   'only',
                action:                 "jQuery('#"+container_id+"').data('slickgridextended').switch_slickgrid_filter_row();"
            });
            options['command_menu_entries'].reverse();                          // restore previous order of elements


            if (options['show_pin_icon']){
                options['command_menu_entries'].push({
                    name:                  'pin_grid_global',
                    caption:                'Pin table',
                    hint:                   locale_translate('slickgrid_pin_global_hint'),
                    icon_class:             'cui-pin',
                    show_icon_in_caption:   'right',
                    action:                 "jQuery('#"+container_id+"').data('slickgridextended').pin_grid(true);",
                    unvisible:              true
                });
                options['command_menu_entries'].push({
                    name:                  'pin_grid_local',
                    caption:                'Pin table',
                    hint:                   locale_translate('slickgrid_pin_local_hint'),
                    icon_class:             'cui-pin',
                    show_icon_in_caption:   'right',
                    action:                 "jQuery('#"+container_id+"').data('slickgridextended').pin_grid(false);"
                });
            }

            options['command_menu_entries'].push({
                name:                   'remove_table_from_page',
                caption:                'Close table',
                hint:                   locale_translate('slickgrid_close_hint'),
                icon_class:             'cui-x',
                show_icon_in_caption:   'right',
                action:                 "jQuery('#"+container_id+"').data('slickgridextended').remove_grid();"
            });


            var show_command_entry_menu = false;                            // assume not showing menu until menu entry requests this
            for (var cmd_index in options['command_menu_entries']) {
                var cmd = options['command_menu_entries'][cmd_index];
                if (cmd['show_icon_in_caption'] !== 'only' && cmd['show_icon_in_caption'] !== 'right'){
                    show_command_entry_menu = true;
                }
            }

            if (show_command_entry_menu) {                                  // Showing menu not suppressed for at least one entry
                var command_menu_id = 'cmd_menu_'+container_id;

                var command_menu_context_id = command_menu_id+'_context_menu';

                caption_left_box.append('<div style="margin-left:5px; margin-right:5px; display: inline-block;" class="slick-shadow">' +
                    '<div id="'+command_menu_id+'" style="padding-left: 10px; padding-right: 10px; background-color: #E0E0E0; cursor: pointer;" title="'+locale_translate('slickgrid_menu_hint')+'">' +
                    '\u2261' + // 3 waagerechte Striche ≡
                    '<div class="contextMenu" id="'+command_menu_context_id+'" style="display:none;">' +
                    '</div></div></div>'
                );

                var command_menu_list = '<ul>';
                var bindings = {};

                for (var cmd_index in options['command_menu_entries']) {
                    var cmd = options['command_menu_entries'][cmd_index];
                    if (cmd['show_icon_in_caption'] != 'only' && cmd['show_icon_in_caption'] != 'right'){
                        command_menu_list = command_menu_list +
                            '<li id="'+command_menu_id+'_'+cmd['name']+'" title="'+cmd['hint']+'"><span class="'+cmd['icon_class']+'" style="float:left;">&nbsp;</span><span>'+cmd['caption']+'</span></li>';
                        bindings[command_menu_id+'_'+cmd['name']] = new Function(cmd['action']); // create function from text

                    }
                }
                command_menu_list = command_menu_list + '</ul>';
                jQuery('#'+command_menu_context_id).html(command_menu_list);

                jQuery("#"+command_menu_id).contextMenu(command_menu_context_id, {
                    menuStyle: {  width: '340px' },
                    bindings:   bindings, onContextMenu : function(event, menu) // dynamisches Anpassen des Context-Menü
                    {
                        return true;
                    }
                });

                jQuery("#"+command_menu_id).bind('click' , function( event) {
                    jQuery("#"+command_menu_id).trigger("contextmenu", event);
                    return false;
                });
            }


            // Check for icons in left box of caption line
            for (var cmd_index in options['command_menu_entries']) {
                var cmd = options['command_menu_entries'][cmd_index];
                if (cmd['show_icon_in_caption'] && cmd['show_icon_in_caption'] !== 'right' ){   // show icon in caption line of grid ?
                    caption_left_box.append('<div style="margin-left:5px; margin-top:4px; cursor: pointer; display: inline-block;"'+
                        'title="'+cmd['hint'] + '" onclick="'+ cmd['action'] +'">' +
                        '<span class="'+cmd['icon_class']+'"></span>' +
                        '</div>');
                }
            }


            // Check for icons in right box of caption
            for (var cmd_index in options['command_menu_entries']) {
                var cmd = options['command_menu_entries'][cmd_index];
                if (cmd['show_icon_in_caption'] === 'right' ){              // show icon in caption line of grid but right ?
                    caption_right_box.append('<span id="'+container_id+'_header_left_box_'+cmd['name']+'"'+
                        ' style="margin-right:3px; margin-top:4px; cursor: pointer;'+((cmd['unvisible']) ? 'display: none;' : '')+'"'+
                        ' title="'+cmd['hint'] + '" onclick="'+ cmd['action'] +'">' +
                        '<span class="'+cmd['icon_class']+'"></span>' +
                        '</span>');
                }
            }
        }

        dataView.setFilter(options["data_filter"]);                             // optinaler Filter auf Daten

    }   // initialize_slickgrid

    /**
     * Event-handler if column has been resized
     *
     * @param grid  SlickGrid-Object
     */
    function processColumnsResized(grid){
        for (var col_index in grid.getColumns()){
            var column = grid.getColumns()[col_index];
            // Value of column.previousWidth contains fractions since last Slickgrid release
            if (Math.round(column.previousWidth) !== Math.round(column.width)){ // Breite dieser Spalte wurde resized durch drag
                column.fixedWidth = column.width;                               // Diese spalte von Kalkulation der Spalten ausnehmen
            }
        }
 //       grid.getOptions()["rowHeight"] = 1;                                   //Neuberechnung der wirklich benötigten Höhe auslösen
        thiz.calculate_current_grid_column_widths("processColumnsResized");
        //grid.render();                                                        // Grid neu berechnen und zeichnen
    }

    /**
     * Aufbau der Zellen zur Ermittlung Höhe und Breite
     */
    function init_test_cells(){
        // DIVs anlegen am Ende des Grids für Test der resultierenden Breite von Zellen für slickGrid
        var test_cell_id                = 'test_cell'               +container_id;
        var test_cell_wrap_id           = 'test_cell_wrap'          +container_id;
        var test_cell_height_id         = 'test_cell_height'        +container_id;
        var test_cell_header_id         = 'test_cell_header'        +container_id;
        var test_cell_header_name_id    = 'test_cell_header_name'   +container_id;
        var test_cells_outer = jQuery(
            '<div>'+
            //Tables für Test der resultierenden Hoehe und Breite von Zellen für slickGrid
            // Zwei table für volle Zeichenbreite
            '<div class="slick-inner-cell" style="visibility:hidden; position:absolute; left: 0px; z-index: -1; padding: 0; margin: 0; height: 20px; width: 90%;"><nobr><div id="' + test_cell_id + '" style="width: 1px; height: 1px; overflow: hidden;"></div></nobr></div>'+
            // Zwei table für umgebrochene Zeichenbreite
            '<div  class="slick-inner-cell" id="' + test_cell_wrap_id + '" style="visibility:hidden; position:absolute; left: 0px; z-index: -1; width:1px; height:'+jQuery(window).height()/2+'px; padding: 0; margin: 0; word-wrap: normal;"></div>' +
            '</div>'+
            '<div  class="slick-inner-cell" id="' + test_cell_height_id + '" style="visibility:hidden; position:absolute; left: 0px; z-index: -1; height:1px; padding: 0; margin: 0; word-wrap: normal;"></div>' +
            '</div>'+
            '<div id="'+test_cell_header_id+'" class="ui-state-default slick-header-column slick-header-sortable"   style="visibility:hidden; position:absolute; left: 0px; z-index: -1; width:1px; height: 1px; margin: 0; word-wrap: normal;">'+
            '  <span class="slick-column-name" id="'+ test_cell_header_name_id +'"></span>' +
            '  <span class="slick-sort-indicator"></span>' +
            '</div>'
        );

        thiz.gridContainer.after(test_cells_outer);                                  // am lokalen Grid unterbringen

        thiz.js_test_cell               = document.getElementById(test_cell_id);        // Objekt zum Test der realen string-Breite
        thiz.js_test_cell_wrap          = document.getElementById(test_cell_wrap_id);   // Objekt zum Test der realen string-Breite
        thiz.js_test_cell_height        = document.getElementById(test_cell_height_id); // Objekt zum Test der realen string-Breite
        thiz.js_test_cell_header        = document.getElementById(test_cell_header_id);
        thiz.js_test_cell_header_name   = document.getElementById(test_cell_header_name_id);
    }

    /**
     * Parsen eines numerischen Wertes aus der landesspezifischen Darstellung mit Komma und Dezimaltrenner
     * @param value String-Darstellung
     * @returns float-value
     */
    this.parseFloatLocale = function(value){
        if (value === "")
            return 0;
        if (options['locale'] === 'en'){                                               // globale Option vom Aufrufer
            return parseFloat(value.replace(/\,/g, ""));
        } else {
            return parseFloat(value.replace(/\./g, "").replace(/,/,"."));
        }
    };

    /**
     * Ausgabe eines numerischen Wertes in der landesspezifischen Darstellung mit Komma
     * @param value Float-Wert
     * @returns String-value
     */
    this.printFloatLocale = function(value, precision){
        var rounded_value = Math.round(value * Math.pow(10, precision)) / Math.pow(10, precision);
        if (options['locale'] === 'en'){                                               // globale Option vom Aufrufer
            return String(rounded_value);
        } else {
            return String(rounded_value).replace(/\./g, ",");
        }
    };


    /**
     * Ermitteln Column-Objekt nach Name
     *
     * @param name  Column name
     * @returns {*}
     */
    this.getColumnByName = function(name){
        for (var col_index in thiz.all_columns) {
            var column = thiz.all_columns[col_index];
            if (column.name === name){
                return column;
            }
        }
        return null;                                                            // nichts gefunden
    };

    /**
     * Translate key into string according to options[:locale]
     *
     * @param key
     */
    var locale_translate = function(key){
        var sl_locale = options['locale'];

        if (get_slickgrid_translations()[key]){
            if (get_slickgrid_translations()[key][sl_locale]){
                return get_slickgrid_translations()[key][sl_locale];
            } else {
                if (get_slickgrid_translations()[key]['en'])
                    return get_slickgrid_translations()[key]['en'];
                else
                    return 'No default translation (en) available for key "'+key+'"';
            }
        } else {
            return 'No translation available for key "'+key+'"';
        }
    };

    // privileged function fuer Zugriff von aussen
    this.ext_locale_translate = function(key){ return locale_translate(key); };


    /**
     * Filtern einer Zeile des Grids gegen aktuelle Filter
     * @param item          data array row
     * @returns {boolean}   show row according to filter
     */
    function slickgrid_filter_item_row(item) {
         for (var columnId in columnFilters) {
            if (columnId !== undefined && columnFilters[columnId] !== "") {
                var c = thiz.grid.getColumns()[thiz.grid.getColumnIndex(columnId)];
                if (c.sort_type === "float" &&  item[c.field] !== columnFilters[columnId]) {
                    return false;
                }
                if (c.sort_type !== "float" &&  (item[c.field].toUpperCase().match(columnFilters[columnId].toUpperCase())) == null ) {
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * Calculate height of header row
     */
    this.calculate_header_height = function(columns){
        // Hoehen von Header so setzen, dass der komplette Inhalt dargestellt wird
        var header_height = 1

        columns.forEach(column => {
            if (column.header_wrap_height > header_height){                     // Check only if max. height of header cell may increase options['headerHeight']
                thiz.js_test_cell_header_name.innerHTML = column.name;
                thiz.js_test_cell_header.style.width = (column.width-9)+'px';   // column width reduced by 2*padding=4 + 1*border=1
                if (thiz.js_test_cell_header.scrollHeight > header_height){
                    header_height = thiz.js_test_cell_header.scrollHeight;
                }
            }
        });
        trace_log('calculate_header_height = '+header_height);
        return header_height - 4;                                               // reduced by padding-top because scrollheight counts inside padding
    }

    /**
     * Calculate row height
     */
    this.calculate_row_height= function(columns, options){
        const row_height_addition = 2;                                          // 1px border-top + 1px border-bottom  hinzurechnen
        var row_height = options['rowHeight']

        if (options["line_height_single"]){
            row_height = single_line_height() + 7;
        } else {                                                                // Volle notwendige Höhe errechnen
            // Hoehen von Cell so setzen, dass der komplette Inhalt dargestellt wird, aber wenigstens eine Zeile im Ganzen sichtbar bleibt

            // Ermitteln der max. Zeilen-Höhe für ganze Zeile im sichtbaren Bereich
            var max_visible_row_height = jQuery(window).height() / 3;           // 1/3 der sichtbare Browser-Hoehe
            if (options['maxHeight']) {
                max_visible_row_height = options['maxHeight'] / 3;
            }

            var slick_inner_cells = this.gridContainer.find(".slick-inner-cell");
            if (slick_inner_cells.length == 0){                                 // use fake div for first column instead of grid's cells
                var data = this.grid.getData().getItems();
                if (data.length > 0 ){                                          // at least one record in result
                    var rec = data[0];
                    this.grid.getColumns().forEach((column, index) => {
                        // calculate decorated content of cell
                        var column_metadata = rec.metadata.columns[column.field];  // Metadata der Spalte der Row
                        var fullvalue = HTML_Formatter_prepare(this, 0, column.position, rec[column.field], column, rec, column_metadata);
                        //fullvalue =  fullvalue.replace(/<wbr>/g, '');                       // entfernen von vordefinierten Umbruchstellen, da diese in der Testzelle sofort zum Umbruch führen und die Ermittlung der Darstellungsbreite fehlschlägt
                        if (column['cssClass'])
                            fullvalue = "<span class='" +column['cssClass']+ "'>"+fullvalue+"</span>";
                        this.js_test_cell_height.innerHTML = fullvalue;
                        this.js_test_cell_height.style.width = column.width+'px'; // set test cell with to current width of column
                        var scrollHeight = this.js_test_cell_height.scrollHeight;
                        if (row_height < scrollHeight)                                  // Inhalt steht nach unten über
                            row_height = scrollHeight + row_height_addition;            // 1px border-top + 1px border-bottom  hinzurechnen
                        this.js_test_cell_height.innerHTML = '';                                    // leeren der Testzelle, ansonsten könnten z.B. Ziel-DOM-ID's mehrfach existierem
                    });
                }
                row_height = row_height + 7;                                    // inner-cell height + padding-top (2) + padding_bottom(3) + 2 * border
                if (row_height > max_visible_row_height)
                    row_height = max_visible_row_height;                        // Reduzieren auf Limit wenn die Zeile zu hoch würde
            }
            slick_inner_cells.each(function(){                                  // Iteration über alle Zellen des Grid falls diese schon sichtbar sind
                var slick_inner_cell = jQuery(this);
                var scrollHeight = slick_inner_cell.prop("scrollHeight");           // virtuelle Höhe des Inhaltes

                // Normalerweise muss row_height genau 2px groesser sein als scrollHeight (1px border-top + 1px border-bottom  hinzurechnen)
                // wenn row_height größer gewählt wird müssen genau so viel px beim Vergleich von scrollHeight abgezogen werden wie mehr als 2px hinzugenommen werden
                if (row_height < scrollHeight){                                 // Inhalt steht nach unten über
                    row_height = scrollHeight + row_height_addition;            // 1px border-top + 1px border-bottom  hinzurechnen
                }

                if (row_height > max_visible_row_height) {
                    row_height = max_visible_row_height;                        // Reduzieren auf Limit wenn die Zeile zu hoch würde

                    // Ermitteln des Column-Objektes zu colx
                    var column_id = slick_inner_cell.attr('column');
                    var column = columns.find(c => c.id === column_id);         // find column by id

                    var new_css = 'overflow-y: auto;';
                    if (column['style']) {
                        if (column.style.indexOf(new_css) !== -1) {
                            column.style = column.style+' '+new_css;
                        }

                    } else {                                                    // noch kein style definiert
                        column.style = new_css;
                    }
                }
            });
        }
        trace_log('calculate_row_height = '+row_height);
        return row_height;
    }

    /**
     * Fill unsed space in column width until total width reaches current_grid_width
     * @param options
     * @param current_table_width
     * @param current_grid_width
     */
    this.fill_unused_column_space = function(options, columns, current_table_width, current_grid_width){
        // Evtl. Zoomen der Spalten wenn noch mehr Platz rechts vorhanden
        if (options.width === '' || options.width === '100%'){                  // automatische volle Breite des Grid
            var wrapped_colums_remaining = true;                                // assume there are wrapped columns to enlarge at first
            var all_columns_fixed = true;                                       // assume there are no columns to expand
            // fill all columns one by one
            while (current_table_width < current_grid_width){                   // noch Platz am rechten Rand, kann auch nach wrap einer Spalte verbleiben
                var wrapped_column_found = false;
                columns.forEach(function(column) {
                    if (column.width < column.max_nowrap_width)
                        wrapped_column_found = true;
                    if (!column.fixedWidth)
                        all_columns_fixed = false;
                    if (current_table_width < current_grid_width && !column.fixedWidth &&
                        (!wrapped_colums_remaining || column.width < column.max_nowrap_width || column.width < column.header_nowrap_width )
                    ){
                        column.width++;
                        current_table_width++;
                    }
                });
                wrapped_colums_remaining = wrapped_column_found;                // enlarge all not fixed columns in next loops if no wrapped columns are remaining
            }
            if (all_columns_fixed && current_table_width < current_grid_width){ // if all columns are fixed, enlarge the last column
                columns[columns.length-1].width = columns[columns.length-1].width + current_grid_width - current_table_width;
                current_table_width = current_grid_width;
            }
        }
        return current_table_width;                                             // keep changed value for further user
    }

    /**
     * Get width of parent element that controls maximum width of grid
     */
    this.get_grid_parent_width = function(){
        var grid_parent_width;
        if (this.gridContainer.parents().hasClass('flex-row-element'))
            grid_parent_width = this.gridContainer.parents('.flex-row-element').parent().prop('clientWidth');  // erstmal maximale Breit als Client annehmen, wird für auto-Breite später auf das notwendige reduziert
        else
            grid_parent_width = this.gridContainer.parent().prop('clientWidth');  // erstmal maximale Breit als Client annehmen, wird für auto-Breite später auf das notwendige reduziert
        return grid_parent_width;
    }

    /**
     * Berechnung der aktuell möglichen Spaltenbreiten in Abhängigkeit des Parent und anpassen slickGrid
     * Setzen / Löschen der Scrollbars je nach dem wie sie benötigt werden
     * Diese Funktion muss gegen rekursiven Aufruf geschützt werden,recursive from Height set da sie durch diverse Events getriggert wird
     * @param caller    Herkunfts-String
     */
    this.calculate_current_grid_column_widths = function(caller, reset_line_height){
        var options = this.grid.getOptions();
        var viewport_div = this.gridContainer.find('.slick-viewport.slick-viewport-top.slick-viewport-left');

        var current_grid_width = this.get_grid_parent_width();
        var columns = this.grid.getColumns();
        var max_table_width = 0;                                                // max. Summe aller Spaltenbreiten (komplett mit Scrollbereich)
        var column;
        var h_padding       = 10;                                               // Horizontale Erweiterung der Spaltenbreite: padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)

        trace_log(caller+": start calculate_current_grid_column_widths ");

        viewport_div.css('overflow', '');                                        // Default-Einstellung des SlickGrid für Scrollbar entfernen

        columns.forEach(function(column){
            column.width = column.fixedWidth ? column.fixedWidth : column.max_nowrap_width+h_padding; // per Default komplette Breite des Inhaltes als Spaltenbreite annehmen , Korrektur um padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)
            max_table_width += column.width;
        });

        var current_table_width = max_table_width + scrollbarWidth();           // Assume vertical scrollbar is needed, fixed later if no vertical scrollbar

        // Check for possible wrap in column to reduce width of grid
        var more_wrap_possible = true;                                          // Assume more wraps are possible
        while (current_table_width > current_grid_width && more_wrap_possible) {    // until target width reached or no more reduction possible
            more_wrap_possible = false;                                         // Assume no wrap is possible until column states the opposite
            columns.forEach(function(column){
                if (   current_table_width > current_grid_width                         // Verkleinerung der Breite notwendig?
                    && column['width']     > column['max_wrap_width']+h_padding         // diese spalte könnte verkleinert werden
                    && !column['fixedWidth']
                    && !column['no_wrap']
                ) {
                    column['width']--;
                    current_table_width--;
                    if (column['width'] > column['max_wrap_width']+h_padding)   // more wrapping is possible in next loop
                        more_wrap_possible = true;
                }
            });
        }

        current_table_width = this.fill_unused_column_space(options, columns, current_table_width, current_grid_width);   // Enlarge columns up to current_grid_width if possible

        var needs_horizontal_scrollbar = current_table_width-scrollbarWidth() > current_grid_width - 1;
        trace_log(caller+": needs_horizontal_scrollbar = "+ needs_horizontal_scrollbar);

        var row_height = this.calculate_row_height(columns, options);       // get row height based on previously set column width

        options['headerHeight'] = this.calculate_header_height(columns);

        var total_height = options['headerHeight']                          // innere Höhe eines Headers
            + 8                                                             // padding top und bottom=4 des Headers
            + 2                                                             // border=1 top und bottom des headers
            + (row_height * this.grid.getDataLength() )                     // Höhe aller Datenzeilen
            + (needs_horizontal_scrollbar ? scrollbarWidth() : 0)
            + (options["showHeaderRow"] ? options["headerRowHeight"] : 0)
            + 1                                                             // Karrenz wegen evtl. Rundungsfehler
        ;

        var total_scroll_height = total_height;                                 // Wirkliche sichtbare Höhe
        if (options['maxHeight'] && options['maxHeight'] < total_height)
            total_scroll_height = options['maxHeight'];                         // Limitieren der Höhe auf Vorgabe wenn sonst überschritten

        var needs_vertical_scrollbar = total_scroll_height < total_height;
        trace_log(caller+": needs_vertical_scrollbar = "+ needs_vertical_scrollbar);

        if (!needs_vertical_scrollbar)                                          // use unused space for vertical scrollbar for columns
            current_table_width = this.fill_unused_column_space(options, columns, current_table_width-scrollbarWidth(), current_grid_width);


        this.gridContainer.data('last_resize_width', this.get_grid_parent_width()); // Merken der aktuellen Breite des Parents, um unnötige resize-Events zu vermeiden

        if (options['width'] === "auto"){
            var vertical_scrollbar_width = needs_vertical_scrollbar ? scrollbarWidth() : 0;
            if (max_table_width+vertical_scrollbar_width < current_grid_width)
                this.gridContainer.css('width', max_table_width+vertical_scrollbar_width);  // Grid kann noch breiter dargestellt werden
            else
                this.gridContainer.css('width', current_grid_width);  // Gesamtes Grid auf die Breite des Parents setzen
        }
        jQuery('#caption_'+this.gridContainer.attr('id')).css('width', this.gridContainer.width()); // Breite des Caption-Divs auf Breite des Grid setzen

        options['rowHeight']    = row_height;
        this.gridContainer.data('total_height', total_height);              // Speichern am DIV-Objekt für Zugriff aus anderen Funktionen
        this.gridContainer.height(total_scroll_height);                     // Aktivieren Höhe incl. setzen vertikalem Scrollbar wenn nötig
        this.grid.setOptions(options);                                          // Setzen der veränderten options am Grid
        this.grid.setColumns(columns);                                      // Setzen der veränderten Spaltenweiten am slickGrid, löst onScroll-Ereignis aus mit evtl. wiederholtem aufruf dieser Funktion, daher erst am Ende setzen

        viewport_div.css('overflow-x', (needs_horizontal_scrollbar ? 'scroll' : 'hidden') );
        viewport_div.css('overflow-y', (needs_vertical_scrollbar ? 'scroll' : 'hidden'));                           // force remove vertical scrollbar if not needed (especially for Safari)

        columns.forEach(function(column) {
            trace_log(column.name+ ': width='+column.width);
        });
        trace_log(caller+": end calculate_current_grid_column_widths");
    };

    /**
     * Aufbau context-Menu für slickgrid, Parameter: DOM-ID, Array mit Entry-Hashes
     * @param table_id
     * @param menu_entries
     */
    function build_slickgrid_context_menu(table_id,  menu_entries){
        var options = thiz.grid.getOptions();
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
            jQuery("<li id='"+context_menu_id+"_"+name+"' title='"+hint+"'><span class='"+icon_class+"' style='float:left'>&nbsp;</span><span id='"+context_menu_id+"_"+name+"_label'>"+label+"</span></li>").appendTo(ul);
            bindings[context_menu_id+"_"+name] = click_action;

        }

        menu_entry("sort_column",       'cui-sort-ascending',               function(){ thiz.last_slickgrid_contexmenu_col_header.click();} );                  // Menu-Eintrag Sortieren
        menu_entry("search_filter",     'cui-magnifying-glass',             function(){ thiz.switch_slickgrid_filter_row();} );                                 // Menu-Eintrag Filter einblenden / verstecken
        menu_entry("export_csv",        'cui-file-xls',                     function(){ grid2CSV(table_id);} );                                            // Menu-Eintrag Export CSV
        menu_entry("column_sum",        'cui-settings',                     function(){ show_column_stats(thiz.last_slickgrid_contexmenu_column_name);} );      // Menu-Eintrag Spaltensumme
        menu_entry("field_content",     'cui-zoom-in',                      function(){ show_full_cell_content(thiz.last_slickgrid_contexmenu_field_content);} ); // Menu-Eintrag Feld-Inhalt
        menu_entry("line_height_single", 'cui-text-height',                 function(){ options['line_height_single'] = !options['line_height_single']; thiz.calculate_current_grid_column_widths("context menu line_height_single");} );


        if (options['plotting']){
            // Menu-Eintrag Spalte in Diagramm
            menu_entry("plot_column",     'cui-chart-line',     function(){ plot_slickgrid_diagram(table_id, options['plot_area_id'], options['caption'], thiz.last_slickgrid_contexmenu_column_name, options['multiple_y_axes'], options['show_y_axes']);} );
            // Menu-Eintrag Alle entfernen aus Diagramm
            menu_entry("remove_all_from_diagram", 'cui-trash',         function(){
                    var columns = thiz.grid.getColumns();
                    for (var col_index in columns){
                        columns[col_index]['plottable'] = 0;
                    }
                    plot_slickgrid_diagram(table_id, options['plot_area_id'], options['caption'], null);  // Diagramm neu zeichnen
                }
            );
        }

        menu_entry("sort_method", 'cui-calculator',      function(){
                if (options['sort_method'] === 'QuickSort'){
                    options['sort_method'] = 'BubbleSort';
                } else {
                    options['sort_method'] = 'QuickSort';
                }
                jQuery("#"+context_menu_id+"_sort_method_label")
                    .html(locale_translate('slickgrid_context_menu_sort_method_'+options['sort_method']))
                    .attr('title', locale_translate('slickgrid_context_menu_sort_method_'+options['sort_method']+'_hint'));
            },
            locale_translate('slickgrid_context_menu_sort_method_'+options['sort_method']),
            locale_translate('slickgrid_context_menu_sort_method_'+options['sort_method']+'_hint')
        );

        for (var entry_index in menu_entries){
            menu_entry(entry_index, menu_entries[entry_index]['ui_icon'], menu_entries[entry_index]['action'], menu_entries[entry_index]['label'], menu_entries[entry_index]['hint']);
        }

        // basiert auf ContextMenu - jQuery plugin for right-click context menus, Author: Chris Domigan, http://www.trendskitchens.co.nz/jquery/contextmenu/
        thiz.gridContainer.contextMenu(context_menu_id, {
            menuStyle: {  width: '330px' },
            bindings:   bindings,
            onContextMenu : function(event, menu)                                   // dynamisches Anpassen des Context-Menü
            {
                var cell = $(event.target);
                thiz.last_slickgrid_contexmenu_col_header = null;                        // Initialisierung, um nachfolgend Treffer zu testen

                if (cell.parents(".slickgrid_header_"+table_id).length > 0){        // Mouse-Event fand in Unterstruktur des Spalten-Headers statt
                    cell = cell.parents(".slickgrid_header_"+table_id);             // Zeiger auf Spaltenheader stellen
                }
                if (cell.hasClass("slickgrid_header_"+table_id)){                   // Mouse-Event fand direkt im Spalten-Header oder innerhalb statt
                    thiz.last_slickgrid_contexmenu_col_header = cell;
                    thiz.last_slickgrid_contexmenu_column_name = cell.data('column')['field']
                }
                if (cell.parents(".slick-cell").length > 0){                        // Mouse-Event fand in Unterstruktur der Zelle statt
                    cell = cell.parents(".slick-cell");                             // Zeiger auf äußerstes DIV der Zelle stellen
                }
                if (cell.hasClass("slick-cell")){                                   // Mouse-Event fand in äußerstem DIV der Zelle oder innerhalb statt
                    var slick_header = thiz.gridContainer.find('.slick-header-columns');
                    cell = cell.find(".slick-inner-cell");                          // Inneren DIV mit Spalten-Info suchen
                    thiz.last_slickgrid_contexmenu_col_header = slick_header.children('[id$=\"'+cell.attr('column')+'\"]');  // merken der Header-Spalte des mouse-Events;
                    thiz.last_slickgrid_contexmenu_column_name = cell.attr('column');
                    thiz.last_slickgrid_contexmenu_field_content = cell.text();
                }

                if (thiz.last_slickgrid_contexmenu_col_header) {                         // konkrete Spalte ist bekannt
                    var column = thiz.grid.getColumns()[thiz.grid.getColumnIndex(thiz.last_slickgrid_contexmenu_column_name)];
                    jQuery('#header_'+context_menu_id)
                        .html('Column: <b>'+thiz.last_slickgrid_contexmenu_col_header.html()+'</b>')
                        .css('background-color','lightgray');

                    jQuery("#"+context_menu_id+"_plot_column_label").html(locale_translate(column['plottable'] ? "slickgrid_context_menu_switch_col_from_diagram" : "slickgrid_context_menu_switch_col_into_diagram"));
                    jQuery("#"+context_menu_id+"_line_height_single_label").html(locale_translate(options["line_height_single"] ? "slickgrid_context_menu_line_height_full" : "slickgrid_context_menu_line_height_single"));
                } else {
                    jQuery('#header_'+context_menu_id)
                        .html('Column/cell not exactly hit! Please retry.')
                        .css('background-color','red');
                }
                jQuery("#"+context_menu_id+"_search_filter_label").html(locale_translate(thiz.grid.getOptions()["showHeaderRow"] ? "slickgrid_context_menu_hide_filter" : "slickgrid_context_menu_show_filter"));
                return true;
            }
        });
    }

    /**
     * Ein- / Ausblenden der Filter-Inputs in Header-Rows des Slickgrids
     */
    this.switch_slickgrid_filter_row = function(){
        var options = thiz.grid.getOptions();
        if (options["showHeaderRow"]) {
            thiz.grid.setHeaderRowVisibility(false);
            thiz.grid.getData().setFilter(options["data_filter"]);              // Ruecksetzen auf externen data_filter falls gesetzt, sonst null
        } else {
            thiz.grid.setHeaderRowVisibility(true);
            thiz.grid.getData().setFilter(options["searchFilter"]);
        }
        thiz.grid.setColumns(thiz.grid.getColumns());                                     // Auslösen/Provozieren des Events onHeaderRowCellRendered für slickGrid
        thiz.calculate_current_grid_column_widths("switch_slickgrid_filter_row");  // Höhe neu berechnen
    };

    function grid2CSV(grid_id) {
        function escape(cell){
            return cell.replace(/"/g,"\\\"").replace(/'/g,"\\\'").replace(/;/g, "\\;");
        }

        try {
            var grid_div = jQuery("#"+grid_id);
            var grid = grid_div.data("slickgrid");
            var data = "";


            //Header
            grid_div.find(".slick-header-columns").children().each(function(index, element) {
                data += '"'+escape(jQuery(element).text())+'";'
            });
            data += "\n";

            // Zellen
            var grid_data    = grid.getData().getItems();
            var grid_columns = grid.getColumns();

            for (var data_index in grid_data){
                for (var col_index in grid_columns){
                    data += '"'+escape(grid_data[data_index][grid_columns[col_index]['field']])+'";'
                }
                data += "\n"
            }


            var byteNumbers = new Uint8Array(data.length);

            for (var i = 0; i < data.length; i++)
            {
                byteNumbers[i] = data.charCodeAt(i);
            }
            var blob = new Blob([byteNumbers], {type: "text/csv"});

            // Construct the uri
            var uri = URL.createObjectURL(blob);

            // Construct the <a> element
            var link = document.createElement("a");
            link.download = 'Panorama_Export.csv';
            link.href = uri;

            document.body.appendChild(link);
            link.click();

            // Cleanup the DOM
            document.body.removeChild(link);
            //delete link;

        } catch(e) {
            alert('Error in grid2CSV: '+(e.message === undefined ? 'No error message provided' : e.message)+'! Eventually using FireFox will help.');
        }
//            document.location.href = 'data:Application/download,' + encodeURIComponent(data);     // vorherige Variante
    }

    // Anzeige der Statistik aller Zeilen der Spalte (Summe etc.)
    function show_column_stats(column_name){
        var column          = thiz.grid.getColumns()[thiz.grid.getColumnIndex(column_name)];
        var data            = thiz.grid.getData().getItems();
        var sum             = 0;
        var average         = null;
        var count           = 0;
        var distinct        = {};
        var distinct_count  = 0;
        for (var row_index in data){
            sum += thiz.parseFloatLocale(data[row_index][column_name]);
            count ++;
            distinct[data[row_index][column_name]] = 1;     // Wert in hash merken
        }
        for (var i in distinct) {
            distinct_count += 1;
        }

        if (count > 0)
            average = sum/count;
        show_full_cell_content("Sum = "+sum+"<br/>Average = "+average+"<br/>Count = "+count+"<br/>Count distinct = "+distinct_count);
    }

    /**
     * Anzeige des kompletten Inhaltes der Zelle
     *
     * @param content
     */
    function show_full_cell_content(content){
        // remove a-tags from content
        var wrapped = jQuery("<div>" + content + "</div>");
        wrapped.find("a").replaceWith(function() { return jQuery(this).html(); });
        content = wrapped.html();

        var div_id = 'slickgrid_extended_alert_box';

        // create div for dialog at body if not exists
        if (!jQuery('#'+div_id).length){
            jQuery('body').append('<div id="'+div_id+'" stype=""></div>');
        }
        jQuery("#"+div_id)
            .html(content)
            .dialog({
                    title:'',
                    draggable:  true,
                    width:      jQuery(window).width()*0.5,
                    maxHeight:  jQuery(window).height()*0.9,
                    beforeClose:function(){jQuery('#'+div_id).html('')}     // clear div before close dialog
            })
        ;

    }

    /**
     * Setzen/Limitieren der Höhe des Grids auf maximale Höhe des Inhaltes
     */
    function adjust_real_grid_height(){
        // Einstellen der wirklich notwendigen Höhe des Grids (einige Browser wie Safari brauchen zum Aufbau des Grids Platz für horizontalen Scrollbar, auch wenn dieser am Ende nicht sichtbar wird
        var total_height = thiz.gridContainer.data('total_height');             // gespeicherte Inhaltes-Höhe aus calculate_current_grid_column_widths
        //console.log('adjust_real_grid_height: total_height old='+total_height+' thiz.gridContainer.height()='+thiz.gridContainer.height());
        if (total_height < thiz.gridContainer.height())                         // Sicherstellen, dass Höhe des Containers nicht größer als Höhe des Grids mit allen Zeilen sichtbar
            thiz.gridContainer.height(total_height);
    }

    /**
     * Justieren des Grids nach Abschluss der Resize-Operation mit unterem Schieber
     */
    function finish_vertical_resize(){
        // Ab jetzt die gesetzte Höhe als Vorgabewert verwenden
        var options = thiz.grid.getOptions();
        options['maxHeight'] = thiz.gridContainer.height();
        thiz.grid.setOptions(options);

        thiz.calculate_current_grid_column_widths('finish_vertical_resize');    // Neuberechnen breiten (neue Situation bzgl. vertikalem Scrollbar)
        adjust_real_grid_height();                                              // Limitieren Höhe

    }

    /**
     *  data im fortlaufende id erweitern
     * @param data
     * @param columns
     */
    function init_data(data, columns){
        for (var data_index in data){
            var data_row = data[data_index];
            data_row['id'] = data_index;                                        // Data-Array fortlaufend durchnumerieren
            if (!data[data_index]['metadata'])
                data[data_index]['metadata'] = {columns: {}};                   // Metadata-Objekt anlegen wenn noch nicht existiert
            for (var col_index in columns){                                     // Iteration über Columns
                var col = columns[col_index];
                if (!data_row['metadata']['columns'][col['field']])
                    data_row['metadata']['columns'][col['field']] = {};         // Metadata für alle Spalten anlegen  TODO: warum?
            }
        }
    }
    /**
     * Ermittlung Spaltenbreite der Header auf Basis der konketen Inhalte
     *
     * @param columns
     * @param container_id
     */
    function init_columns_and_calculate_header_column_width(columns, container_id){
        function init_column(column, key, value){
            if (!column[key])
                column[key] = value;                            // Default-Attribut der Spalte, braucht damit nicht angegeben werden
        }

        var column;                                                             // aktuell betrachtete Spalte

        // Ermittlung max. Zeichenbreite ohne Umbrüche
        for (var col_index in columns){
            column = columns[col_index];

            init_column(column, 'formatter',    HTMLFormatter);                 // Default-Formatter, braucht damit nicht angegeben werden
            init_column(column, 'sortable',     true);
            init_column(column, 'sort_type',    'string');                      // Sort-Type. TODO Ermittlung nach JavaScript verschieben
            init_column(column, 'field',        column['id']);                  // Field-Referenz in data-Record muss nicht angegeben werden wenn identisch
            init_column(column, 'minWidth',     5);                             // Default von 30 reduzieren
            init_column(column, 'headerCssClass', 'slickgrid_header_'+container_id);
            init_column(column, 'slickgridExtended', thiz);                     // Referenz auf SlickGridExtended fuer Nutzung ausserhalb
            init_column(column, 'position',     col_index);

            thiz.js_test_cell_header.style.width = '';
            thiz.js_test_cell_header_name.innerHTML = column.name;
            column.header_nowrap_width  = thiz.js_test_cell_header.scrollWidth; // genutzt für Test auf Umbruch des Headers, dann muss Höhe der Header-Zeile angepasst werden

            thiz.js_test_cell_header.style.width = '1px';
            column.max_wrap_width      = thiz.js_test_cell_header.scrollWidth-10;  // min. Breite mit Umbruch muss trotzdem noch den Sort-Pfeil darstellen können
            column.header_wrap_height  = thiz.js_test_cell_header.scrollHeight;                      // max. height of header cell if all words are wrapped


            column.max_nowrap_width    = column.max_wrap_width;                 // Normbreite der Spalte mit Mindestbreite des Headers initialisieren (lieber Header umbrechen als Zeilen einer anderen Spalte)
        }
    }
    /**
     * Options um Defaults erweitern
     *
     * @param options
     */
    function init_options(options){
        function init_option(key, value){
            if (!options[key])
                options[key] = value;                            // Default-Attribut der Option, braucht damit nicht angegeben werden
        }

        init_option('enableCellNavigation', true);
        init_option('headerRowHeight',      30);                // Höhe der optionalen Filter-Zeile
        init_option('enableColumnReorder',  false);
        init_option('width',                'auto');
        init_option('locale',               'en');
        init_option('sort_method',          'QuickSort');                       // QuickSort (Array.sort) oder BubbleSort
    }
    /**
     * Speichern Inhalt und Erneutes Berechnen der Breite und Höhe einer Zelle nach Änderung ihres Inhaltes + Aktualisieren der Anzeige,
     * um kompletten neuen Content zeigen zu können (nicht abgeschnitten)
     *
     * @param obj jQuery-Objekt auf dem innerhalb einer Zelle ein ajax-Call ausgelöst wurde
     */
    this.save_new_cell_content = function(obj){
        var inner_cell = obj.parents(".slick-inner-cell");
        // var grid_table = inner_cell.parents(".slickgrid_top");                      // Grid-Table als jQuery-Objekt
        var column = null;
        for (var column_index in this.grid.getColumns()){
            if (this.grid.getColumns()[column_index]['field'] === inner_cell.attr('column'))
                column = this.grid.getColumns()[column_index];
        }
        // Rückschreiben des neuen Dateninhaltes in Metadata-Struktur des Grid
        this.grid.getData().getItems()[inner_cell.attr("row")][inner_cell.attr("column")] = inner_cell.text();  // sichtbarer Anteil der Zelle
        this.grid.getData().getItems()[inner_cell.attr("row")]["metadata"]["columns"][inner_cell.attr("column")]["fulldata"] = inner_cell.html(); // Voller html-Inhalt der Zelle

        this.calc_cell_dimensions(inner_cell.html(), column);     // Neu-Berechnen der max. Größen durch getürkten Aufruf der Zeichenfunktion
        this.calculate_current_grid_column_widths('recalculate_cell_dimension'); // Neuberechnung der Zeilenhöhe, Spaltenbreite etc. auslösen, auf jeden Fall, da sich die Höhe verändert haben kann
    };


    function scrollbarWidth() {
        if (scrollbarWidth_internal_cache)
            return scrollbarWidth_internal_cache;
        var div = $('<div style="width:50px;overflow-x:scroll;"><div id="scrollbarWidth_testdiv">Hugoplusadditionalinfo</div></div>');
        // Append our div, do our calculation and then remove it
        $('body').append(div);
        scrollbarWidth_internal_cache = div.innerHeight() - div.find("#scrollbarWidth_testdiv").height();
        $(div).remove();
        trace_log("measured scrollbarWidth = "+scrollbarWidth_internal_cache);
        return scrollbarWidth_internal_cache;
    }
    /**
     * Zeichnen eines Diagrammes mit den Daten einer slickgrid-Spalte
     *
     * @param table_id          ID der Table
     * @param plot_area_id      jQuery-Selector des DIVs fuer Plotting
     * @param caption           Kopfzeile
     * @param column_id         Name der Spalte, die ein/ausgeschalten wird
     * @param multiple_y_axes
     * @param show_y_axes
     */
    function plot_slickgrid_diagram(table_id, plot_area_id, caption, column_id, multiple_y_axes, show_y_axes) {
        var options = thiz.grid.getOptions();
        var columns = thiz.grid.getColumns();                          // JS-Objekt mit Spalten-Struktur gespeichert an DOM-Element, Originaldaten des Slickgrid, daher kein Speichern nötig
        var data    = thiz.grid.getData().getItems();                  // JS-Aray mit Daten-Struktur gespeichert an DOM-Element, Originaldaten des Slickgrid, daher kein Speichern nötig

        function get_numeric_content(celldata){ // Ermitteln des numerischen html-Inhaltes einer TD-Zelle bzw. ihrer Kinder, wenn weitere enthalten sind
            if (celldata == '')
                return 0;
            if (options['locale'] === 'de'){
                return parseFloat(celldata.replace(/\./g, "").replace(/,/,"."));   // Deutsche nach englische Float-Darstellung wandeln (Dezimatrenner, Komma)
            }
            if (options['locale'] === 'en'){
                return parseFloat(celldata.replace(/\,/g, ""));                   // Englische Float-Darstellung wandeln, Tausend-Separator entfernen
            }
            return "Error: unsupported locale "+options['locale'];
        }

        function get_date_content(celldata){ // Ermitteln des html-Inhaltes einer TD-Zelle bzw. ihrer Kinder, wenn weitere enthalten sind, als Date
            var parsed_field;
            if (options['locale'] === 'de'){
                var all_parts = celldata.split(" ");
                var date_parts = all_parts[0].split(".");
                parsed_field = date_parts[2]+"/"+date_parts[1]+"/"+date_parts[0]+" "+all_parts[1];   // Datum ISO neu zusammengsetzt + Zeit
            }
            if (options['locale'] === 'en'){
                // change "-" or unbreakable hyphen to "/", because only this way can be parsed in constructor
                parsed_field= celldata.replace(/-/g,"/").replace(/\u2011/g, "/");
            }
            return new Date(parsed_field+" GMT");
        }

        //Sortieren eines DataArray nach dem ersten Element des inneren Arrays (X-Achse)
        function data_array_sort(a,b){
            return a[0] - b[0];
        }

        // Spaltenheader der Spalte mit class 'plottable' versehen oder wegnehmen wenn bereits gesetzt (wenn Column geschalten wird)
        for (var col_index in columns){
            if (columns[col_index]['id'] === column_id){
                if (columns[col_index]['plottable'] === 1)
                    columns[col_index]['plottable'] = 0;
                else
                    columns[col_index]['plottable'] = 1
            }
        }

        var plot_master_column_index = null;                                        // Spalten-Nr. der Plotmaster-Spalte
        var plot_master_column_id = null;                                           // Spalten-Name der Plotmaster-Spalte
        var plot_master_time_column_index=null;                                     // Spalten-Nr. der Plotmaster-Spalte, wenn diese Zeit als Inhalt hat
        var plotting_column_count = 0;                                              // Anzahl der zu zeichnenden Spalten
        for (var column_index in columns) {
            var column = columns[column_index];                                     // konkretes Spalten-Objekt aus DOM
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
            if (column['plottable'] === 1){
                plotting_column_count++;
            }
        }
        if (plot_master_column_index == null){
            alert('Error: No <th>-column has class "plot_master"! Exactly one column of this class is expected!');
        }

        var x_axis_time = false;                                                    // Defaut, wenn keine plot_master_time gesetzt werden
        var data_array = [];
        var plotting_index = 0;
        var smallest_y_value = 0;
        // Iteration ueber plotting-Spalten
        for (var column_index in columns) {
            var column = columns[column_index];                                     // konkretes Spalten-Objekt aus DOM
            if (column['plottable']===1){                                            // nur fuer zu zeichnenden Spalten ausführen
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
                    if (y_val < smallest_y_value)                               // look for smallest value
                        smallest_y_value = y_val;
                    // Plot-Master-Spalte
                    if (plot_master_time_column_index){
                        x_val = get_date_content(data[data_index][plot_master_column_id]).getTime();       // Zeit in ms seit 1970
                        x_axis_time = true;       // mindestens ein plot_master_time gesetzt werden
                    } else {
                        x_val = get_numeric_content(data[data_index][plot_master_column_id]);
                    }
                    col_data_array.push( [ x_val, y_val ]);
                }
                col_data_array.sort(data_array_sort);                           // Data_Array der Spalte nach X-Achse sortieren
                var col_attr = {label:column['name'],
                    delete_callback: thiz.plot_chart_delete_callback,                // aufgerufen von plot_diagram beim Entfernen einer Kurve aus Diagramm
                    data: col_data_array
                };
                data_array.push(col_attr);   // Erweiterung des primären arrays
                plotting_index = plotting_index + 1;  // Weiterzaehlen Index
            }
        }

        var yaxis_options = { show: show_y_axes };
        if (smallest_y_value == 0)
            yaxis_options.min = 0;                                              // allow drawing of negative values if they exist

        plot_diagram(
            table_id,
            plot_area_id,
            caption,
            data_array,
            {   plot_diagram: { locale: options['locale'], multiple_y_axes: multiple_y_axes},
//                yaxis:        { min: 0, show: show_y_axes },
                yaxis:        yaxis_options,
                xaxes: (x_axis_time ? [{ mode: 'time'}] : [{}])
            }
        );
    } // plot_slickgrid_diagram
    /**
     * Callback aus plot_diagram wenn eine Kurve entfernt wurde, denn plottable der Spalte auf 0 drehen
     *
     * @param legend_label
     */
    this.plot_chart_delete_callback = function(legend_label){
        var columns = thiz.grid.getColumns();
        for (var column_index in columns) {
            if (columns[column_index]['name'] === legend_label) {
                columns[column_index]['plottable'] = 0;                         // diese Spalte beim nächsten plot_diagram nicht mehr mit zeichnen
            }
        }
    };

    /**
     * Berechnen der Dimensionen einer konkreten Zelle, native Javascript instead of jQuery because it's heavy frequented
     *
     * @param test_html     content of column cell to measure. single cell or <br>-separated list of cell values
     * @param column        column-object for test
     */
    this.calc_cell_dimensions = function(test_html, column){
        var js_test_cell        = thiz.js_test_cell;
        var js_test_cell_wrap   = thiz.js_test_cell_wrap;

        js_test_cell.innerHTML = test_html;                                 // Test-DOM nowrapped mit voll dekoriertem Inhalt füllen

        if (js_test_cell.scrollWidth  > column.max_nowrap_width){
            column.max_nowrap_width  = js_test_cell.scrollWidth;
        }
        if (!column.no_wrap  && js_test_cell.scrollWidth > column.max_wrap_width){     // Nur Aufrufen, wenn max_wrap_width sich auch vergrößern kann (aktuelle Breite > bisher größte Wrap-Breite)
            js_test_cell_wrap.innerHTML = test_html;                        // Test-DOM wrapped mit voll dekoriertem Inhalt füllen

            if (js_test_cell_wrap.scrollWidth  > column.max_wrap_width){
                if (column.max_wrap_width_allowed && column.max_wrap_width_allowed < js_test_cell_wrap.scrollWidth )
                    column.max_wrap_width  = column.max_wrap_width_allowed;
                else
                    column.max_wrap_width  = js_test_cell_wrap.scrollWidth;
            }
            js_test_cell_wrap.innerHTML = '';                           // leeren der Testzelle, ansonsten könnten z.B. Ziel-DOM-ID's mehrfach existierem
        }
        js_test_cell.innerHTML = '';                                    // leeren der Testzelle, ansonsten könnten z.B. Ziel-DOM-ID's mehrfach existierem
    };

    /**
     * Ermittlung der Zeilenhöhe fuer einzeilige Darstellung
     * @returns {*}
     */
    function single_line_height() {
        thiz.js_test_cell.innerHTML = '1';

        return thiz.js_test_cell.scrollHeight;
    }

    // public function to pin all elements of grid
    // Move Grid to another new parent to prevent it from being overwritten by parent reload
    // this requires all belonging elements of slickgrid (incl. external javascript etc.) are within the parent
    // Parameter: pin_at_toplevel   - boolean
    this.pin_grid = function(pin_at_toplevel){
        if (!options['top_level_container_id']){
            throw "Value for SlickGridExtended-option 'top_level_container_id' ist needed to process pin_grid"
        }

        if (options['update_area']){
            jQuery('#'+ options['update_area']).html('');
        }

        var grid_parent = thiz.gridContainer.parent();

        if (pin_at_toplevel){
            var target_for_pinned = jQuery('#'+options['top_level_container_id']);
            var pin_button_outer_span = jQuery('#'+container_id+'_header_left_box_pin_grid_global');
            var new_title = locale_translate('slickgrid_pinned_global_hint');
            jQuery('#'+container_id+'_header_left_box_pin_grid_local').css('display', 'none');      // hide local pin button if global was hit
            pin_button_outer_span.css('background-color', 'lightgray');         // mark pin button special as global pin
        } else {
            var target_for_pinned = grid_parent;
            var pin_button_outer_span = jQuery('#'+container_id+'_header_left_box_pin_grid_local');
            var new_title = locale_translate('slickgrid_pinned_local_hint');
            jQuery('#'+container_id+'_header_left_box_pin_grid_global').css('display', 'inline');      // show global pin button after local pin

            for (var i = 1; i < options['show_pin_icon']; i++) {                // step up for parents according to number of parent_tree_depth
                target_for_pinned = target_for_pinned.parent();
            }
            if (target_for_pinned.attr('id') == options['top_level_container_id']){
                thiz.pin_grid(true);                                            // treat as top level pin if called from directly from first page after menu action
                return;
            }
        }

        var new_parent = jQuery('<div id="pinned_container_'+container_id+'"></div>').insertBefore(target_for_pinned);
        new_parent.append(grid_parent.children());                                  // move all elements of grid's parent to new paren

        var pin_button_span = pin_button_outer_span.find('.cui-pin');
        pin_button_span.removeClass('cui-pin');
        pin_button_span.addClass('cuis-pin');
        pin_button_span.parent()
            .attr('title', new_title)
            .css('cursor', 'default')
            .attr('onclick', null)
        ;

        // set new titile for close button: closes also descendants
        jQuery('#'+container_id+'_header_left_box_remove_table_from_page').attr('title', locale_translate('slickgrid_close_descendants_hint'));


        thiz.pinned = true;                                                     // remember pinned-status for close-handling
    };


    this.remove_grid = function(){
        if (thiz.pinned){                                                       // remove whole parent div including descendants of grid
            jQuery('#'+container_id).parent().remove();
        } else {                                                                // remove detailed elements of grid from parent
            jQuery('#caption_'+container_id).remove();
            jQuery('#'+container_id).remove();
            jQuery('#menu_'+container_id).remove();
        }
    }



} // Ende SlickGridExtended


// ############################# global functions ##############################

/**
 * Fangen des Resize-Events des Browsers und Anpassen der Breite aller slickGrids
 */
function resize_slickGrids(){
    jQuery('.slickgrid_top').each(function(index, element){
        var gridContainer = jQuery(element);
        var sle = gridContainer.data('slickgridextended');
        if (gridContainer.data('last_resize_width') &&
            sle &&
            gridContainer.data('last_resize_width') !== sle.get_grid_parent_width() && // width of grid has really changed
            gridContainer.is(':visible') &&                                     // suppress calculation of row heights if grid is not visible because scrollHeight of test cells is 0 in this case
            gridContainer.data('slickgrid')                                     // data element is set before
        ) {
            // darf nur in Rekalkulation der Höhe laufen wenn sich Spaltenbreiten verändern
            // für vertikalen Resize muss Höhenberechnung übersprungen werden
            sle.calculate_current_grid_column_widths("resize_slickGrids", true);
            gridContainer.data('last_resize_width', sle.get_grid_parent_width()); // persistieren Aktuelle Breite
        }
    });
}

var TO = false;
// Empfänger der Resize-events
function resize_handler(){
    if(TO !== false)
        clearTimeout(TO);
    TO = setTimeout(resize_slickGrids, 100); //200 is time in miliseconds
}


// Calculate dimension for every cell exactly one time
// process column by column to reduce changes in cell style
function async_calc_all_cell_dimensions(slickGrid, current_column, start_row){

    var columns         = slickGrid.grid.getColumns();
    var data            = slickGrid.grid.getData().getItems();
    var column          = columns[current_column];

    var max_rows_to_process = 5000;

    batch_calc_cell_dimensions(slickGrid, column, start_row, max_rows_to_process);

    if (start_row + max_rows_to_process < data.length){                                             // not all rows processed with initial request
        setTimeout(async_calc_all_cell_dimensions, 0, slickGrid, current_column, start_row + max_rows_to_process);  // Erneut Aufruf einstellen für den Rest des Arrays dieser Spalte
    } else {                                                                    // all Rows processed in this loop
        column['width_calculation_finished'] = true;                            // signal for single cell draws
        if (current_column < columns.length-1){                                 // not all columns processed ?
            setTimeout(async_calc_all_cell_dimensions, 0, slickGrid, current_column+1, 0);  // Erneut Aufruf einstellen für Daten der naechsten Spalte
        } else {
            slickGrid.calculate_current_grid_column_widths('async_calc_all_cell_dimensions'); // calculate grid at end of last call, second time call
        }
    }
}


/**
 * Calculate width dimension for next x rows of column
 *
 * @param slickGrid         das SlickGridExtended-Objekt
 * @param column            Spaltendefinition
 * @param start_row         row-Nr. beginnend mit 0
 * @param max_rows          maximum number of rows to process
 */
function batch_calc_cell_dimensions(slickGrid, column, start_row, max_rows){
    var data;
    var current_row     = start_row;
    var test_html       = '';                                                   // inner HTML

    if (slickGrid.grid){                                                        // Slickgrid already fully initialized ?
        data = slickGrid.grid.getData().getItems();
    } else {
        data = slickGrid.data_items;                                            // direct access to data array as initialization parameter
    }

    while (current_row < data.length && current_row < start_row+max_rows){
        var rec = data[current_row];
        var column_metadata = rec['metadata']['columns'][column['field']];  // Metadata der Spalte der Row

        if (!column_metadata['dc']){
            column_metadata['dc'] = true;
            var fullvalue = HTML_Formatter_prepare(slickGrid, current_row, column['position'], rec[column['field']], column, rec, column_metadata);

            fullvalue =  fullvalue.replace(/<wbr>/g, '');                       // entfernen von vordefinierten Umbruchstellen, da diese in der Testzelle sofort zum Umbruch führen und die Ermittlung der Darstellungsbreite fehlschlägt

            if (column['cssClass'])
                fullvalue = "<span class='" +column['cssClass']+ "'>"+fullvalue+"</span>";

            test_html = test_html + fullvalue+ "<br/>";
        }
        current_row++;
    }

    slickGrid.calc_cell_dimensions(test_html, column);
}




/**
 * Aufbereitung der anzuzeigenden Daten mit optionaler Berechnung der Abmessungen
 * Liefert den vollständig gerenderten Wert für die Zelle
 *
 * @param slickGrid         das SlickGridExtended-Objekt
 * @param row               row-Nr. beginnend mit 0
 * @param cell              cell-Nr. beginnend mit 0
 * @param value             Wert der Zelle in data
 * @param columnDef         Spaltendefinition
 * @param dataContext       komplette Zeile aus data-Array
 * @param column_metadata   die Metadaten der konkreten Spalte der Row
 * @returns {string}
 */
function HTML_Formatter_prepare(slickGrid, row, cell, value, columnDef, dataContext, column_metadata){
    var fullvalue = value;                                                      // wenn keine dekorierten Daten vorhanden sind, dann Nettodaten verwenden
    if (column_metadata['fulldata'])
        fullvalue = column_metadata['fulldata'];                                // Ersetzen des data-Wertes durch komplette Vorgabe incl. html-tags etc.

    if (columnDef['field_decorator_function']){                                 // Decorator-Funktion existiert für Spalte, dann ausführen
        fullvalue = columnDef['field_decorator_function'](slickGrid, row, cell, value, fullvalue, columnDef, dataContext);
    }

    return fullvalue;
}


/**
 * Default-Formatter für Umsetzung HTML in SlickGrid
 *
 * @param row           row-Nr. beginnend mit 0
 * @param cell          cell-Nr. beginnend mit 0
 * @param value         Wert der Zelle in data
 * @param columnDef     Spaltendefinition
 * @param dataContext   komplette Zeile aus data-Array
 * @returns {string}
 */
function HTMLFormatter(row, cell, value, columnDef, dataContext){
    var column_metadata = dataContext['metadata']['columns'][columnDef['field']];  // Metadata der Spalte der Row
    var slickGrid = columnDef['slickgridExtended'];

    var fullvalue = HTML_Formatter_prepare(slickGrid, row, cell, value, columnDef, dataContext, column_metadata);   // Aufbereitung der anzuzeigenden Daten mit optionaler Berechnung der Abmessungen

    if (!column_metadata['dc']){                                            // bislang fand noch keine Messung der Dimensionen der Zellen dieser Zeile statt
        batch_calc_cell_dimensions(slickGrid, columnDef, row, 100);         // Calculate next 100 records for this column
    }

    var output = "<div class='slick-inner-cell' row="+row+" column='"+columnDef['field']+"'";           // sichert u.a. 100% Ausdehnung im Parent und Wiedererkennung der Spalte bei Mouse-Events

    var title = '';
    if (column_metadata['title']) {
        title = column_metadata['title'];
    } else {
        if (columnDef['toolTip'])
            title = columnDef['toolTip']
    }
    if (columnDef['show_pct_hint'] && columnDef['column_sum'] > 0 ){
        var pct_value = slickGrid.parseFloatLocale(value) * 100 / columnDef['column_sum'];
        title += "\n\n= "+ slickGrid.printFloatLocale(pct_value, 2) + ' % ' + slickGrid.ext_locale_translate('slickgrid_pct_hint') + ' ' + slickGrid.printFloatLocale(columnDef['column_sum'], 0);
    }
    if (title.length > 0){
        output += " title='"+title+"'";
    }

    var style = "";
    if (column_metadata['style'])
        style += column_metadata['style'];
    if (columnDef['style'])
        style += columnDef['style'];
    if (!columnDef['no_wrap'])
        style += "white-space: normal; ";
    if (style !== "")
        output += " style='"+style+"'";
    output += ">";

    if (columnDef['show_pct_background'] && columnDef['column_sum'] > 0 ){
        var pct_value = Math.round(slickGrid.parseFloatLocale(value) * 100 / columnDef['column_sum']);
        output += "<div "+
              "style='background-image: -webkit-linear-gradient(left, gray 0%, lightgray "+pct_value+"%, rgba(255, 255, 255, 0) "+pct_value+"%, rgba(255, 255, 255, 0) 100%); "+
                     "background-image: -moz-linear-gradient(left, gray 0%, lightgray "+pct_value+"%, rgba(255, 255, 255, 0) "+pct_value+"%, rgba(255, 255, 255, 0) 100%);    "+
                     "background-image: linear-gradient(left, gray 0%, lightgray "+pct_value+"%, rgba(255, 255, 255, 0) "+pct_value+"%, rgba(255, 255, 255, 0) 100%);         "+
                     "'>" +
              fullvalue + "</div>"
    } else {
        output += fullvalue
    }
    output += "</div>";
    return output;
}


function trace_log(msg){
    if (false){
        console.log(msg);                                                           // Aktivieren trace-Ausschriften
    }
}
/**
 * Übersetzungsliste
 *
 * @returns {string}
 */
function get_slickgrid_translations() {
    return {
        'slickgrid_close_hint': {
            'en': 'Remove this table from page',
            'de': 'Entfernen der Tabelle von Seite'
        },
        'slickgrid_close_descendants_hint': {
            'en': "Remove this table and all it's possible descendants from page",
            'de': "Entfernen der Tabelle und aller ihrer eventuellen Nachkömmlinge von Seite"
        },
        'slickgrid_context_menu_column_sum': {
            'en': 'Sums of all rows of this column',
            'de': 'Summen der Werte dieser Spalte'
        },
        'slickgrid_context_menu_column_sum_hint': {
            'en': 'Calculate numeric sum and count for all rows of this column',
            'de': 'Numerische Summe und Anzahl Zeilen dieser Spalte anzeigen'
        },
        'slickgrid_context_menu_export_csv': {
            'en': 'Export grid in csv-file'
        },
        'slickgrid_context_menu_export_csv_hint': {
            'en': 'Export grid in csv-file for import to Excel etc. (to browsers default download folder)',
            'de': 'Export grid in csv-file für import nach Excel etc. (in Standard-Download-Verzeichnis)'
        },
        'slickgrid_context_menu_field_content': {
            'en': 'Show content of table cell',
            'de': 'Anzeige des Inhaltes des Tabellenfeldes'
        },
        'slickgrid_context_menu_field_content_hint': {
            'en': 'Show content of table cell in popup window (for better copy & paste)',
            'de': 'Anzeige des Inhaltes des Tabellenfeldes in Popup-Fenster (zum Markieren und Kopieren)'
        },
        'slickgrid_context_menu_hide_filter': {
            'en': 'Hide search filter',
            'de': 'Suchfilter ausblenden'
        },
        'slickgrid_context_menu_line_height_full': {
            'en': 'Line height for full visible content',
            'de': 'Zeilenhöhe für volle Anzeige Feldinhalt'
        },
        'slickgrid_context_menu_line_height_single': {
            'en': 'Line height for single line only',
            'de': 'Zeilenhöhe für einzeiligen Text'
        },
        'slickgrid_context_menu_line_height_single_hint': {
            'en': 'Switch between single text line in row and display of complete content',
            'de': 'Wechsel zwischen einzeiligem Text und Anzeige des kompletten Feld-Inhaltes'
        },
        'slickgrid_context_menu_plot_column_hint': {
            'en': 'Add/remove column to graphic timeline diagram',
            'de': 'Hinzufügen/Löschen der Spalte aus grafischem Zeitleisten-Diagramm'
        },
        'slickgrid_context_menu_remove_all_from_diagram': {
            'en': 'Remove all graphs from diagram',
            'de': 'Alle Kurven aus Diagramm entfernen'
        },
        'slickgrid_context_menu_remove_all_from_diagram_hint': {
            'en': 'Remove all column-graphs from current diagram',
            'de': 'Antfernen aller Spalten-Kurven aus dem aktuellen Diagramm'
        },
        'slickgrid_context_menu_search_filter_hint': {
            'en': 'Show/hide column-specific search filter in first line of table',
            'de': 'Anzeigen/Ausblenden des spalten-spezifischen Suchfilters in erster Zeile der Tabelle'
        },
        'slickgrid_context_menu_show_filter': {
            'en': 'Show search filter',
            'de': 'Suchfilter einblenden'
        },
        'slickgrid_context_menu_sort_column': {
            'en': 'Sort by this column',
            'de': 'Nach dieser Spalte sortieren'
        },
        'slickgrid_context_menu_sort_column_hint': {
            'en': 'Sort table by this column. Each click switches between ascending and descending order',
            'de': 'Sortieren der Tabelle nach dieser Spalte. Wechselt zwischen aufsteigender und absteigender Folge.'
        },
        'slickgrid_context_menu_switch_col_into_diagram': {
            'en': 'Show column in diagram',
            'de': 'Spalte in Diagramm einblenden'
        },
        'slickgrid_context_menu_switch_col_from_diagram': {
            'en': 'Remove column from diagram',
            'de': 'Spalte aus Diagramm ausblenden'
        },
        'slickgrid_context_menu_sort_method_QuickSort': {
            'en': 'Switch column sort method to bubble sort',
            'de': 'Sortier-Methode auf Bubble-Sort wechseln'
        },
        'slickgrid_context_menu_sort_method_BubbleSort': {
            'en': 'Switch column sort method to quick sort',
            'de': 'Sortier-Methode auf Quick-Sort wechseln'
        },
        'slickgrid_context_menu_sort_method_QuickSort_hint': {
            'en': 'Switch sort method for table columns to bubble sort.\nSorts slower but remains last sort order for equal values of current sort-column.\nAllows multi-column sort by subsequent sorting of columns',
            'de': 'Wechsel der Sortier-Methode für Tabellenspalten auf Bubble-Sort.\nSortiert langsamer, aber erhält die vorherige Sortierfolge bei gleichen Werten der aktuellen Sortierspalte.\nErlaubt somit mehrspaltiges Sortieren durch aufeinanderfolgendes Klicken der zu sortierenden Spalten)'
        },
        'slickgrid_context_menu_sort_method_BubbleSort_hint': {
            'en': 'Switch sort method for table columns to quick sort.\n Sorts faster but ignores previous sort order for equal values of current sort-column',
            'de': 'Wechsel der Sortier-Methode für Tabellenspalten auf Quick-Sort.\nSortiert schnell, aber ignoriert die vorherige Sortierung bei gleichen Werten der aktuellen Sortierspalte'
        },
        'slickgrid_filter_hint_not_numeric': {
            'en': 'Filter by containing string',
            'de': 'Filtern nach enthaltener Zeichenkette'
        },
        'slickgrid_filter_hint_numeric': {
            'en': 'Filter by exact value (incl. thousands-delimiter and comma)',
            'de': 'Filtern nach exaktem Wert (incl. Tausender-Trennung und Komma)'
        },
        'slickgrid_menu_hint': {
            'en': 'Show menu with local functions for this table',
            'de': 'Zeige Menü mit lokalen Funktionen für diese Tabelle'
        },
        'slickgrid_pin_global_hint': {
            'en': "Pin this table global.\nPrevent it from being overwritten by any menu action",
            'de': "Pinnen der Tabelle global.\nVerhindern des Überschreibens durch jegliche Menü-Aktion"
        },
        'slickgrid_pin_local_hint': {
            'en': "Pin this table.\nPrevent it from being overwritten by parent reload",
            'de': "Pinnen der Tabelle.\nVerhindern des Überschreibens beim Reload der Parent-Information"
        },
        'slickgrid_pinned_global_hint': {
            'en': "Table is pinned at top_level.\nClick Close-icon to remove table.",
            'de': "Tabelle ist global auf top-level gepinnt.\nZum Entfernen Close-icon klicken"
        },
        'slickgrid_pinned_local_hint': {
            'en': "Table is pinned.\nClick Close-icon to remove table.",
            'de': "Tabelle ist gepinnt.\nZum Entfernen Close-icon klicken"
        },
        'slickgrid_pct_hint': {
            'en': 'of column sum',
            'de': 'der Spaltensumme von'
        }
    }
}




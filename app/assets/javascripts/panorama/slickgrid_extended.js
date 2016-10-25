"use strict"

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
 * Personal extension for SlickGrid v2.1 (originated by Michael Leibman)
 *
 *
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
    sle.calculate_current_grid_column_widths('createSlickGridExtended');        // Sicherstellen, dass mindestens ein zweites Mal diese Funktion durchlaufen wird und Scrollbars real berücksichtigt werden
    setTimeout(async_calc_all_cell_dimensions, 0, sle, 0);                      // Asynchrone Berechnung der noch nicht vermessenen Zellen für Kalkulation der Dimensionen
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
    var slickgrid_render_needed         = 0;                                    // globale Variable, die steuert, ob aktuell gezeichnetes Grid nach Abschluss neu gerendert werden muss, da sich Größen geändert haben
    var test_cell                       = null;                                 // Objekt zum Test der realen string-Breite für td, wird bei erstem Zugriff initialisiert
    var test_cell_wrap                  = null;                                 // Objekt zum Test der realen string-Breite für td, wird bei erstem Zugriff initialisiert
    var columnFilters                   = {};                                   // aktuelle Filter-Kriterien der Daten
    var sort_pfeil_width                = 12;                                   // Breite des Sort-Pfeils im Column-Header
    this.force_height_calculation       = false;                                // true aktiviert Neuberechnung der Grid-Höhe
    this.last_height_calculation_with_horizontal_scrollbar = false;
    this.grid                           = null;                                 // Referenz auf SlickGrid-Objekt, belegt erst in initSlickGridExtended
    var last_slickgrid_contexmenu_col_header    = null;                         // globale Variable mit jQuery-Objekt des Spalten-Header der Spalte, in der Context-Menu zuletzt gerufen wurd
    var last_slickgrid_contexmenu_column_name   = '';                           // globale Variable mit Spalten-Name der Spalte, in der Context-Menu zuletzt gerufen wurd
    var last_slickgrid_contexmenu_field_content = '';                           // globale Variable mit Inhalt des Feldes auf dem Context-Menu aufgerufen wurde

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
     *                             { label: "Menu-Label", hint: "MouseOver-Hint", ui_icon: "ui-icon-image", action:  function(t){ ActionName } }
     */
    this.initSlickGridExtended = function(container_id, data, columns, options, additional_context_menu){
        this.all_columns = columns;                                             // Column-Deklaration in der Form wie dem SlickGrid übergeben inkl. hidden columns

        var viewable_columns = []
        for (var col_index in columns) {
            var column = columns[col_index];
            if (!column['hidden'])                                              // nur sichtbare Spalten weiter verwenden
                viewable_columns.push(column);
        }

        init_columns_and_calculate_header_column_width(viewable_columns, container_id);  // columns um Defaults und Weiten-Info der Header erweitern
        init_data(data, columns);                                               // data im fortlaufende id erweitern, auch für hidden columns
        init_options(options);                                                  // Options um Defaults erweitern
        init_test_cells();                                                      // hidden DIV-Elemente fuer Groessentest aufbauen

        var dataView = new Slick.Data.DataView();
        dataView.setItems(data);
        options["searchFilter"] = slickgrid_filter_item_row;                    // merken filter-Funktion für Aktivierung über Menü
        //dataView.setFilter(slickgrid_filter_item_row);

        if (options['maxHeight'] && !jQuery.isNumeric(options['maxHeight'])) {  // Expression set instead of numeric value for pixel
            options['maxHeight'] = eval(options['maxHeight']);                  // execute expression to get height in px
        }
        options['maxHeight'] = Math.round(options['maxHeight']);                // Sicherstellen Ganzzahligkeit

        options['headerHeight']  = 1;                                           // Default, der später nach Notwendigkeit größer gesetzt wird
        options['rowHeight']     = 1;                                           // Default, der später nach Notwendigkeit größer gesetzt wird

        options['plotting']      = false;                                       // Soll Diagramm zeichenbar sein: Default=false wenn nicht eine Spalte als x-Achse deklariert ist
        for (var col_index in viewable_columns) {
            var column = viewable_columns[col_index];
            if (options['plotting'] && (column['plot_master'] || column['plot_master_time']))
                alert('Es kann nur eine Spalte einer Tabelle Plot-Master für X-Achse sein');
            if (column['plot_master'] || column['plot_master_time'])
                options['plotting'] = true;

            if (column['show_pct_hint'] || column['show_pct_background']){
                var column_sum = 0
                for (var row_index in data){
                    column_sum += this.parseFloatLocale(data[row_index]['col'+col_index]);  // Kumulieren der Spaltensumme
                }
                column['column_sum'] = column_sum;
            }
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

        // auskommentiert weil calculate_current_grid_column_widths erst nach asynchronem calc_cell_dimensions Sinn macht
        //this.calculate_current_grid_column_widths('setup_slickgrid');           // erstmalige Berechnung der Größen

        // auskommentiert weil calculate_current_grid_column_widths erst nach asynchronem calc_cell_dimensions Sinn macht
        //adjust_real_grid_height();                                              // Anpassen der Höhe des Grid an maximale Höhe des Inhaltes

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

                if (col['sort_type'] == "float") {
                    sortFunc  = function(a, b) {
                        return thiz.parseFloatLocale(a[field]) - thiz.parseFloatLocale(b[field]);
                    }
                } else if (col['sort_type'] == "date" && options['locale'] == 'de'){
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

                if (col['sort_type'] == "float"){
                    sort_smaller = function(value1, value2){
                        return thiz.parseFloatLocale(value1) < thiz.parseFloatLocale(value2);
                    }
                }

                if (col['sort_type'] == "date" && options['locale'] == 'de'){              // englisches Date lässt sich als String sortieren
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
            if (grid.getOptions()['sort_method'] == 'QuickSort'){
                quickSort();
            } else if (grid.getOptions()['sort_method'] == 'BubbleSort'){
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

//        grid.onScroll.subscribe(function(){
//            if (thiz.slickgrid_render_needed ==1){
//                thiz.calculate_current_grid_column_widths('onScroll');
//            }
//        });

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
            $("<input type='text' style='font-size: 11.5; width: 100%;' title='"+input_hint(args.column.id)+"'>")
                .data("columnId", args.column.id)
                .val(columnFilters[args.column.id])
                .appendTo(args.node);
        });

        grid.onDblClick.subscribe(function(e, args){
            show_full_cell_content(jQuery(grid.getCellNode(args['row'], args['cell'])).children().text());  // Anzeige des Zell-Inhaltes
        });

        // Caption setzen
        if (options['caption'] && options['caption'] != ""){
            var caption = jQuery("<div id='caption_"+container_id.replace(/#/, "")+"' class='slick-caption slick-shadow'></div>").insertBefore('#'+container_id);
            caption.html(options['caption'])
        }

        dataView.setFilter(options["data_filter"]);                       // optinaler Filter auf Daten

    }   // initialize_slickgrid

    /**
     * Event-handler if column has been resized
     *
     * @param grid  SlickGrid-Object
     */
    function processColumnsResized(grid){
        for (var col_index in grid.getColumns()){
            var column = grid.getColumns()[col_index];
            if (column['previousWidth'] != column['width']){                        // Breite dieser Spalte wurde resized durch drag
                column['fixedWidth'] = column['width'];                             // Diese spalte von Kalkulation der Spalten ausnehmen
            }
        }
 //       grid.getOptions()["rowHeight"] = 1;                                         //Neuberechnung der wirklich benötigten Höhe auslösen
        thiz.calculate_current_grid_column_widths("processColumnsResized");
        //grid.render();                                                              // Grid neu berechnen und zeichnen
    }

    /**
     * Aufbau der Zellen zur Ermittlung Höhe und Breite
     */
    function init_test_cells(){
        // DIVs anlegen am Ende des Grids für Test der resultierenden Breite von Zellen für slickGrid
        var test_cell_id        = 'test_cell'       +container_id;
        var test_cell_wrap_id   = 'test_cell_wrap'  +container_id;
        var test_cells_outer = jQuery(
            '<div>'+
                //Tables für Test der resultierenden Hoehe und Breite von Zellen für slickGrid
                // Zwei table für volle Zeichenbreite
                '<div class="slick-inner-cell" style="visibility:hidden; position: absolute; z-index: -1; padding: 0; margin: 0; height: 20px; width: 90%;"><nobr><div id="' + test_cell_id + '" style="width: 1px; height: 1px; overflow: hidden;"></div></nobr></div>'+
                // Zwei table für umgebrochene Zeichenbreite
                //'<table style="visibility:hidden; position:absolute; width:1px;"><tr><td class="slick-inner-cell"  style="padding: 0; margin: 0;"><div id="' + test_cell_wrap_id + '"></div></td></tr></table>' +
                '<div  class="slick-inner-cell" id="' + test_cell_wrap_id + '" style="visibility:hidden; position:absolute; width:1px; padding: 0; margin: 0; word-wrap: normal;"></div>' +
                '</div>'
        );

        thiz.gridContainer.after(test_cells_outer);                                  // am lokalen Grid unterbringen

        thiz.test_cell       = test_cells_outer.find('#'+test_cell_id);         // Objekt zum Test der realen string-Breite
        thiz.test_cell_wrap  = test_cells_outer.find('#'+test_cell_wrap_id);    // Objekt zum Test der realen string-Breite für td
    }

    /**
     * Parsen eines numerischen Wertes aus der landesspezifischen Darstellung mit Komma und Dezimaltrenner
     * @param value String-Darstellung
     * @returns float-value
     */
    this.parseFloatLocale = function(value){
        if (value == "")
            return 0;
        if (options['locale'] == 'en'){                                               // globale Option vom Aufrufer
            return parseFloat(value.replace(/\,/g, ""));
        } else {
            return parseFloat(value.replace(/\./g, "").replace(/,/,"."));
        }
    }

    /**
     * Ausgabe eines numerischen Wertes in der landesspezifischen Darstellung mit Komma
     * @param value Float-Wert
     * @returns String-value
     */
    this.printFloatLocale = function(value, precision){
        var rounded_value = Math.round(value * Math.pow(10, precision)) / Math.pow(10, precision);
        if (options['locale'] == 'en'){                                               // globale Option vom Aufrufer
            return String(rounded_value);
        } else {
            return String(rounded_value).replace(/\./g, ",");
        }
    }


    /**
     * Ermitteln Column-Objekt nach Name
     *
     * @param name  Column name
     * @returns {*}
     */
    this.getColumnByName = function(name){
        for (var col_index in thiz.all_columns) {
            var column = thiz.all_columns[col_index];
            if (column.name == name){
                return column;
            }
        }
        return null;                                                            // nichts gefunden
    }

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
    }

    // privileged function fuer Zugriff von aussen
    this.ext_locale_translate = function(key){ return locale_translate(key); }


    /**
     * Filtern einer Zeile des Grids gegen aktuelle Filter
     * @param item          data array row
     * @returns {boolean}   show row according to filter
     */
    function slickgrid_filter_item_row(item) {
         for (var columnId in columnFilters) {
            if (columnId !== undefined && columnFilters[columnId] !== "") {
                var c = thiz.grid.getColumns()[thiz.grid.getColumnIndex(columnId)];
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

    /**
     * Testen, ob DOM-Objekt vertikalen Scrollbar besitzt
     * @returns {boolean}
     */
    function has_slickgrid_vertical_scrollbar(){
        var viewport = thiz.gridContainer.find(".slick-viewport");
        var scrollHeight = viewport.prop('scrollHeight');
        var clientHeight = viewport.prop('clientHeight');
        // Test auf vertikalen Scrollbar nur vornehmen, wenn clientHeight wirklich gesetzt ist und dann Differenz zu ScrollHeight
        return clientHeight > 0 && scrollHeight > clientHeight;
    }

    /**
     * Berechnung der aktuell möglichen Spaltenbreiten in Abhängigkeit des Parent und anpassen slickGrid
     * Setzen / Löschen der Scrollbars je nach dem wie sie benötigt werden
     * Diese Funktion muss gegen rekursiven Aufruf geschützt werden,recursive from Height set da sie durch diverse Events getriggert wird
     * @param caller    Herkunfts-String
     */
    this.calculate_current_grid_column_widths = function(caller){
        var options = this.grid.getOptions();
        var viewport_div = this.gridContainer.children('.slick-viewport')

        var current_grid_width = this.gridContainer.parent().prop('clientWidth');           // erstmal maximale Breit als Client annehmen, wird für auto-Breite später auf das notwendige reduziert
        var columns = this.grid.getColumns();
        var original_widths = [];
        var max_table_width = 0;                                                // max. Summe aller Spaltenbreiten (komplett mit Scrollbereich)
        var column;
        var h_padding       = 10;                                               // Horizontale Erweiterung der Spaltenbreite: padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)

        trace_log(caller+": start calculate_current_grid_column_widths ");

        this.slickgrid_render_needed = 0;                                       // Falls das Flag gesetzt war, wird das rendern jetzt durchgeführt und Flag damit entwertet

        viewport_div.css('overflow', '')                                        // Default-Einstellung des SlickGrid für Scrollbar entfernen

        for (var col_index in columns) {
            var column = columns[col_index];
            original_widths.push(column['width']);                              // Merken der ursprünglichen Breite für Vergleich nach Berechnung

            if (column['fixedWidth']){
                if (column['width'] != column['fixedWidth']) {                  // Feste Breite vorgegeben ?
                    column['width']      = column['fixedWidth'];                // Feste Breite der Spalte beinhaltet bereits padding
                }

            } else {                                                            // keine feste Breite vorgegeben
                if (column['width'] != column['max_nowrap_width']+h_padding) {
                    column['width']      = column['max_nowrap_width']+h_padding;// per Default komplette Breite des Inhaltes als Spaltenbreite annehmen , Korrektur um padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)
                }
            }

            max_table_width += column['width'];
        }
        // Prüfen auf Möglichkeit des Umbruchs in der Zelle
        var current_table_width = max_table_width;                              // Summe aller max. Spaltenbreiten
        if (has_slickgrid_vertical_scrollbar()){
            current_table_width += scrollbarWidth();
        }

        // console.log('Grid_Container='+this.gridContainer.prop('id')+' current_grid_width='+current_grid_width+' max_table_width='+max_table_width);
        // Neuimplementierung wrap
        for (var col_index in columns) {
            column = columns[col_index];
            if (   current_table_width > current_grid_width                         // Verkleinerung der Breite notwendig?
                && column['width']     > column['max_wrap_width']+h_padding         // diese spalte könnte verkleinert werden
                && !column['fixedWidth']
                && !column['no_wrap']
            ) {
                var wrap_diff = column['width'] - (column['max_wrap_width']+h_padding);  // max. mögliche Reduktion der Breite durch wrap
                if (current_table_width - wrap_diff < current_grid_width) {         // Es muss nicht um den möglichen Betrag verkleinert werden
                    wrap_diff = current_table_width - current_grid_width;           // notwendiger Rest an Verkleinerung für Paaafähigkeit ohne horiz. Scrollen
                }
                // console.log('Grid_Container='+this.gridContainer.prop('id')+' column='+column['name']+' width='+column['width']+' shrinked by '+wrap_diff);
                column['width'] = column['width'] - wrap_diff;
                current_table_width -= wrap_diff;
            }

        }

        // Evtl. Zoomen der Spalten wenn noch mehr Platz rechts vorhanden
        if (options['width'] == '' || options['width'] == '100%'){                  // automatische volle Breite des Grid
            while (current_table_width < current_grid_width){                       // noch Platz am rechten Rand, kann auch nach wrap einer Spalte verbleiben
                for (var col_index in columns) {
                    if (current_table_width < current_grid_width && !columns[col_index]['fixedWidth']){
                        columns[col_index]['width']++;
                        current_table_width++;
                    }
                }
            }
        }

        this.gridContainer.data('last_resize_width', this.gridContainer.parent().width()); // Merken der aktuellen Breite des Parents, um unnötige resize-Events zu vermeiden

        if (options['width'] == "auto"){
            var vertical_scrollbar_width = has_slickgrid_vertical_scrollbar() ? scrollbarWidth() : 0;
            if (max_table_width+vertical_scrollbar_width < current_grid_width)
                this.gridContainer.css('width', max_table_width+vertical_scrollbar_width);  // Grid kann noch breiter dargestellt werden
            else
                this.gridContainer.css('width', current_grid_width);  // Gesamtes Grid auf die Breite des Parents setzen
        }
        jQuery('#caption_'+this.gridContainer.attr('id')).css('width', this.gridContainer.width()); // Breite des Caption-Divs auf Breite des Grid setzen

        // horizontalen Scrollbar setzen / löschen
        var horizontal_scrollbar_width = 0;
        if (current_table_width > current_grid_width){
            viewport_div.css('overflow-x', 'auto');
            horizontal_scrollbar_width = scrollbarWidth();                      // Höhe des Scrollbars muss bei Höhenberechnung des Grids berücksichtigt werden
        }
        else
            viewport_div.css('overflow-x', 'hidden');                           // Absolutes disablen des horizontalen Scrollbars


        var columns_changed = false;                                            // Vergleichen ursrüngliche mit aktuellen Spaltenbreiten
        for (var col_index in columns) {
            if (columns[col_index]['width'] != original_widths[col_index])
                columns_changed = true;
        }

        if (columns_changed){                                                   // nur wenn Spaltenbreite sich aendert, kann sich auch die Darstellung der Header ändern, dann Anpassen options['headerHeight']
            // Hoehen von Header so setzen, dass der komplette Inhalt dargestellt wird
            this.gridContainer.find(".slick-header-columns").children().each(function(){
                var scrollHeight = jQuery(this).prop("scrollHeight");
                var clientHeight = jQuery(this).prop("clientHeight");
                if ( (scrollHeight > clientHeight && scrollHeight-4 > options['headerHeight'] ) || // Inhalt steht nach unten über
                    options['headerHeight'] == 1                                // es hat noch keine Anpassung von Header-Höhe stattgefunden
                ){
                    options['headerHeight'] = scrollHeight-4;                   // Padding hinzurechnen, da Höhe auf Ebene des Zeilen-DIV gesetzt wird
                }
            });
        }

        this.grid.setOptions(options);                                          // Setzen der veränderten options am Grid

        if (columns_changed) {
            trace_log(caller+": call grid.setColumns because columns_changed==true");
            this.grid.setColumns(columns);                                               // Setzen der veränderten Spaltenweiten am slickGrid, löst onScroll-Ereignis aus mit wiederholtem aufruf dieser Funktion, daher erst am Ende setzen
            // dieser Aufruf von this.grid.setColumns(columns); setzt bei Setup erstmalig die Spaltenbreiten, so dass erst danach reale Bemessung der rowHeight möglich wird
        }

        //############### Ab hier Berechnen der Zeilenhöhen ##############
        var row_height    = options['rowHeight'];                               // alter Wert

        if (options["line_height_single"]){
            row_height = single_line_height() + 7;
        } else {                                                                // Volle notwendige Höhe errechnen
            // Hoehen von Cell so setzen, dass der komplette Inhalt dargestellt wird
            this.gridContainer.find(".slick-inner-cell").each(function(){
                var scrollHeight = jQuery(this).prop("scrollHeight");           // virtuelle Höhe des Inhaltes

                // Normalerweise muss row_height genau 2px groesser sein als scrollHeight (1px border-top + 1px border-bottom  hinzurechnen)
                // wenn row_height größer gewählt wirdm müssen genau so viel px beim Vergleich von scrollHeight abgezogen werden wie mehr als 2px hinzugenommen werden
                if (row_height < scrollHeight){                                 // Inhalt steht nach unten über
                    row_height = scrollHeight + 4;                              // 1px border-top + 1px border-bottom  hinzurechnen
                }
            });
        }

        var total_height = options['headerHeight']                              // innere Höhe eines Headers
                + 8                                                             // padding top und bottom=4 des Headers
                + 2                                                             // border=1 top und bottom des headers
                + (row_height * this.grid.getDataLength() )                     // Höhe aller Datenzeilen
                + horizontal_scrollbar_width
                + (options["showHeaderRow"] ? options["headerRowHeight"] : 0)
                + 1                                                             // Karrenz wegen evtl. Rundungsfehler
        ;

        var total_scroll_height = total_height;                                 // Wirkliche sichtbare Höhe
        if (options['maxHeight'] && options['maxHeight'] < total_height)
            total_scroll_height = options['maxHeight'];                         // Limitieren der Höhe auf Vorgabe wenn sonst überschritten

        if (row_height                                              != options['rowHeight']             ||
            total_scroll_height                                     != this.gridContainer.height()      ||
            this.last_height_calculation_with_horizontal_scrollbar  != (horizontal_scrollbar_width > 0) ||      // Änderung der Darstellung horizontaler Scrollbar ?
            this.force_height_calculation
        ){
            trace_log(caller+": calculate_current_grid_column_widths Höhenberechung");
            trace_log(caller+": Grund: row_Height: "                +(row_height                                                != options['rowHeight'])                +
                                     " total_scroll_height: "       +(total_scroll_height                                       != this.gridContainer.height())         +
                                     " horizontal_scrollbar: "      +(this.last_height_calculation_with_horizontal_scrollbar    != (horizontal_scrollbar_width > 0))    +
                                     " force_height_calculation: "  +this.force_height_calculation
            );

            options['rowHeight']    = row_height;
            this.force_height_calculation = false;                              // rücksetzen einmaliger Zwang zur erneuten Höhenberechnung

            this.last_height_calculation_with_horizontal_scrollbar = horizontal_scrollbar_width > 0;

            this.gridContainer.data('total_height', total_height);              // Speichern am DIV-Objekt für Zugriff aus anderen Funktionen

            this.gridContainer.height(total_scroll_height);                     // Aktivieren Höhe incl. setzen vertikalem Scrollbar wenn nötig
            this.grid.setOptions(options);                                      // Setzen der veränderten options am Grid

            trace_log(caller+": call grid.setColumns because height calculation forced");
            this.grid.setColumns(columns);                                      // Setzen der veränderten Spaltenweiten am slickGrid, löst onScroll-Ereignis aus mit evtl. wiederholtem aufruf dieser Funktion, daher erst am Ende setzen
        }
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
            jQuery("<li id='"+context_menu_id+"_"+name+"' title='"+hint+"'><span class='"+icon_class+"' style='float:left'></span><span id='"+context_menu_id+"_"+name+"_label'>"+label+"</span></li>").appendTo(ul);
            bindings[context_menu_id+"_"+name] = click_action;

        }

        menu_entry("sort_column",       "ui-icon ui-icon-carat-2-n-s",      function(){ thiz.last_slickgrid_contexmenu_col_header.click();} );                  // Menu-Eintrag Sortieren
        menu_entry("search_filter",     "ui-icon ui-icon-zoomin",           function(){ switch_slickgrid_filter_row();} );                                 // Menu-Eintrag Filter einblenden / verstecken
        menu_entry("export_csv",        "ui-icon ui-icon-document",         function(){ grid2CSV(table_id);} );                                            // Menu-Eintrag Export CSV
        menu_entry("column_sum",        "ui-icon ui-icon-document",         function(){ show_column_stats(thiz.last_slickgrid_contexmenu_column_name);} );      // Menu-Eintrag Spaltensumme
        menu_entry("field_content",     "ui-icon ui-icon-arrow-4-diag",     function(){ show_full_cell_content(thiz.last_slickgrid_contexmenu_field_content);} ); // Menu-Eintrag Feld-Inhalt
        menu_entry("line_height_single","ui-icon ui-icon-arrow-2-n-s",      function(){ options['line_height_single'] = !options['line_height_single']; thiz.calculate_current_grid_column_widths("context menu line_height_single");} );


        if (options['plotting']){
            // Menu-Eintrag Spalte in Diagramm
            menu_entry("plot_column",     "ui-icon ui-icon-image",     function(){ plot_slickgrid_diagram(table_id, options['plot_area_id'], options['caption'], thiz.last_slickgrid_contexmenu_column_name, options['multiple_y_axes'], options['show_y_axes']);} );
            // Menu-Eintrag Alle entfernen aus Diagramm
            menu_entry("remove_all_from_diagram", "ui-icon ui-icon-trash",         function(){
                    var columns = thiz.grid.getColumns();
                    for (var col_index in columns){
                        columns[col_index]['plottable'] = 0;
                    }
                    plot_slickgrid_diagram(table_id, options['plot_area_id'], options['caption'], null);  // Diagramm neu zeichnen
                }
            );
        }

        menu_entry("sort_method","ui-icon ui-icon-triangle-2-n-s",      function(){
                if (options['sort_method'] == 'QuickSort'){
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
            menu_entry(entry_index, "ui-icon "+menu_entries[entry_index]['ui_icon'], menu_entries[entry_index]['action'], menu_entries[entry_index]['label'], menu_entries[entry_index]['hint']);
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
        //thiz.gridContainer.longpress(function() {alert("Hugo");}, null, 2000);
    }

    /**
     * Ein- / Ausblenden der Filter-Inputs in Header-Rows des Slickgrids
     */
    function switch_slickgrid_filter_row(){
        var options = thiz.grid.getOptions();
        if (options["showHeaderRow"]) {
            thiz.grid.setHeaderRowVisibility(false);
            thiz.grid.getData().setFilter(options["data_filter"]);              // Ruecksetzen auf externen data_filter falls gesetzt, sonst null
        } else {
            thiz.grid.setHeaderRowVisibility(true);
            thiz.grid.getData().setFilter(options["searchFilter"]);
        }
        thiz.grid.setColumns(thiz.grid.getColumns());                                     // Auslösen/Provozieren des Events onHeaderRowCellRendered für slickGrid
        thiz.force_height_calculation = true;                                   // Sicherstellen, dass Höhenberechnung nicht wegoptimiert wird
        thiz.calculate_current_grid_column_widths("switch_slickgrid_filter_row");  // Höhe neu berechnen
    }

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
            alert('Error in grid2CSV: '+(e.message == undefined ? 'No error message provided' : e.message)+'! Eventually using FireFox will help.');
        }
//            document.location.href = 'data:Application/download,' + encodeURIComponent(data);     // vorherige Variante
    }

    // Anzeige der Statistik aller Zeilen der Spalte (Summe etc.)
    function show_column_stats(column_name){
        var column = thiz.grid.getColumns()[thiz.grid.getColumnIndex(column_name)];
        var data   = thiz.grid.getData().getItems();
        var sum   = 0;
        var count = 0;
        var distinct = {};
        var distinct_count = 0;
        for (var row_index in data){
            sum += thiz.parseFloatLocale(data[row_index][column_name])
            count ++;
            distinct[data[row_index][column_name]] = 1;     // Wert in hash merken
        }
        for (var i in distinct) {
            distinct_count += 1;
        }
        alert("Sum = "+sum+"\nCount = "+count+"\nCount distinct = "+distinct_count);
    }

    /**
     * Anzeige des kompletten Inhaltes der Zelle
     *
     * @param content
     */
    function show_full_cell_content(content){
        alert(content);
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
    };

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

        // DIVs für Test der resultierenden Breite von Zellen für slickGrid
        var test_header_outer      = jQuery('<div class="slick_header_column ui-widget-header" style="visibility:hidden; position: absolute; z-index: -1; padding: 0; margin: 0;"><nobr><div id="test_header" style="width: 1px; overflow: hidden;"></div></nobr></div>');
        thiz.gridContainer.after(test_header_outer);                             // Einbinden in DOM-Baum
        var test_header         = test_header_outer.find('#test_header');       // Objekt zum Test der realen string-Breite

        // Alte Variante mit TABLE für umgebrochene Zeichenbreite
        //var test_header_wrap_outer = jQuery('<table style="visibility:hidden; position:absolute; width:1px;"><tr><td class="slick_header_column ui-widget-header" style="font-size: 100%; padding: 0; margin: 0;"><div id="test_header_wrap"></div></td></tr></table>');
        //thiz.gridContainer.after(test_header_wrap_outer);                       // Nach Container unsichtbar einbinden
        //var test_header_wrap  = test_header_wrap_outer.find('#test_header_wrap'); // Objekt zum Test der realen string-Breite für td

        var test_header_wrap_outer = jQuery('<div><div id="test_header_wrap" style="visibility:hidden; position:absolute; width:1px; padding: 0; margin: 0;" class="slick_header_column ui-widget-header"></div></div>');
        thiz.gridContainer.after(test_header_wrap_outer);                       // Nach Container unsichtbar einbinden
        var test_header_wrap  = test_header_wrap_outer.find('#test_header_wrap'); // Objekt zum Test der realen string-Breite für td

        var column;                                                             // aktuell betrachtete Spalte

        // Ermittlung max. Zeichenbreite ohne Umbrüche
        for (var col_index in columns){
            column = columns[col_index];

            init_column(column, 'formatter', HTMLFormatter);                    // Default-Formatter, braucht damit nicht angegeben werden
            init_column(column, 'sortable',  true);
            init_column(column, 'sort_type', 'string');                          // Sort-Type. TODO Ermittlung nach JavaScript verschieben
            init_column(column, 'field',     column['id']);                     // Field-Referenz in data-Record muss nicht angegeben werden wenn identisch
            init_column(column, 'minWidth',  5);                                // Default von 30 reduzieren
            init_column(column, 'headerCssClass', 'slickgrid_header_'+container_id);
            init_column(column, 'slickgridExtended', thiz);                     // Referenz auf SlickGridExtended fuer Nutzung ausserhalb


            test_header.html(column['name']);                                   // Test-Zelle mit zu messendem Inhalt belegen
            column['header_nowrap_width']  = test_header.prop("scrollWidth");   // genutzt für Test auf Umbruch des Headers, dann muss Höhe der Header-Zeile angepasst werden

            test_header_wrap.html(column['name']);
            column['max_wrap_width']      = test_header_wrap.prop("scrollWidth"); //  + sort_pfeil_width;  // min. Breite mit Umbruch muss trotzdem noch den Sort-Pfeil darstellen können

            column['max_nowrap_width']    = column['max_wrap_width'];           // Normbreite der Spalte mit Mindestbreite des Headers initialisieren (lieber Header umbrechen als Zeilen einer anderen Spalte)
        }

        // Entfernen der DIVs fuer Breitenermittlung aus dem DOM-Baum
        test_header_outer.remove();
        test_header_wrap_outer.remove();
    };

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
    };


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
            if (this.grid.getColumns()[column_index]['field'] == inner_cell.attr('column'))
                column = this.grid.getColumns()[column_index];
        }
        // Rückschreiben des neuen Dateninhaltes in Metadata-Struktur des Grid
        this.grid.getData().getItems()[inner_cell.attr("row")][inner_cell.attr("column")] = inner_cell.text();  // sichtbarer Anteil der Zelle
        this.grid.getData().getItems()[inner_cell.attr("row")]["metadata"]["columns"][inner_cell.attr("column")]["fulldata"] = inner_cell.html(); // Voller html-Inhalt der Zelle

        this.calc_cell_dimensions(inner_cell.text(), inner_cell.html(), column);     // Neu-Berechnen der max. Größen durch getürkten Aufruf der Zeichenfunktion
        this.calculate_current_grid_column_widths('recalculate_cell_dimension'); // Neuberechnung der Zeilenhöhe, Spaltenbreite etc. auslösen, auf jeden Fall, da sich die Höhe verändert haben kann
    };


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
    };

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
            if (options['locale'] == 'de'){
                return parseFloat(celldata.replace(/\./g, "").replace(/,/,"."));   // Deutsche nach englische Float-Darstellung wandeln (Dezimatrenner, Komma)
            }
            if (options['locale'] == 'en'){
                return parseFloat(celldata.replace(/\,/g, ""));                   // Englische Float-Darstellung wandeln, Tausend-Separator entfernen
            }
            return "Error: unsupported locale "+options['locale'];
        }

        function get_date_content(celldata){ // Ermitteln des html-Inhaltes einer TD-Zelle bzw. ihrer Kinder, wenn weitere enthalten sind, als Date
            var parsed_field;
            if (options['locale'] == 'de'){
                var all_parts = celldata.split(" ");
                var date_parts = all_parts[0].split(".");
                parsed_field = date_parts[2]+"/"+date_parts[1]+"/"+date_parts[0]+" "+all_parts[1];   // Datum ISO neu zusammengsetzt + Zeit
            }
            if (options['locale'] == 'en'){
                parsed_field= celldata.replace(/-/g,"/");       // Umwandeln "-" nach "/", da nur so im Date-Konstruktor geparst werden kann
            }
            return new Date(parsed_field+" GMT");
        }

        //Sortieren eines DataArray nach dem ersten Element des inneren Arrays (X-Achse)
        function data_array_sort(a,b){
            return a[0] - b[0];
        }

        // Spaltenheader der Spalte mit class 'plottable' versehen oder wegnehmen wenn bereits gesetzt (wenn Column geschalten wird)
        for (var col_index in columns){
            if (columns[col_index]['id'] == column_id){
                if (columns[col_index]['plottable'] == 1)
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
            if (column['plottable'] == 1){
                plotting_column_count++;
            }
        }
        if (plot_master_column_index == null){
            alert('Fehler: Keine <th>-Spalte besitzt die Klasse "plot_master"! Exakt eine Spalte mit dieser Klasse wird erwartet');
        }

        var x_axis_time = false;                                                    // Defaut, wenn keine plot_master_time gesetzt werden
        var data_array = [];
        var plotting_index = 0;
        // Iteration ueber plotting-Spalten
        for (var column_index in columns) {
            var column = columns[column_index];                                     // konkretes Spalten-Objekt aus DOM
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
                col_data_array.sort(data_array_sort);                           // Data_Array der Spalte nach X-Achse sortieren
                var col_attr = {label:column['name'],
                    delete_callback: thiz.plot_chart_delete_callback,                // aufgerufen von plot_diagram beim Entfernen einer Kurve aus Diagramm
                    data: col_data_array
                };
                data_array.push(col_attr);   // Erweiterung des primären arrays
                plotting_index = plotting_index + 1;  // Weiterzaehlen Index
            }
        }


        plot_diagram(
            table_id,
            plot_area_id,
            caption,
            data_array,
            {   plot_diagram: { locale: options['locale'], multiple_y_axes: multiple_y_axes},
                yaxis:        { min: 0, show: show_y_axes },
                xaxes: (x_axis_time ? [{ mode: 'time'}] : [{}])
            }
        );
    }; // plot_slickgrid_diagram

    /**
     * Callback aus plot_diagram wenn eine Kurve entfernt wurde, denn plottable der Spalte auf 0 drehen
     *
     * @param legend_label
     */
    this.plot_chart_delete_callback = function(legend_label){
        var columns = thiz.grid.getColumns();
        for (var column_index in columns) {
            if (columns[column_index]['name'] == legend_label) {
                columns[column_index]['plottable'] = 0;                         // diese Spalte beim nächsten plot_diagram nicht mehr mit zeichnen
            }
        }
    }

    /**
     * Berechnen der Dimensionen einer konkreten Zelle
     *
     * @param value
     * @param fullvalue
     * @param column
     */
    this.calc_cell_dimensions = function(value, fullvalue, column){
        var test_cell      = thiz.test_cell;
        var test_cell_wrap = thiz.test_cell_wrap;
        if (!column['last_calc_value'] || (value != column['last_calc_value'] && value.length*9 > column['max_wrap_width'])){  // gleicher Wert muss nicht erneut gecheckt werden, neuer Wert muss > alter sein bei 10 Pixel Breite, aber bei erstem Male durchlauen
            fullvalue =  fullvalue.replace(/<wbr>/g, '');                       // entfernen von vorderfinierten Umbruchstellen, da diese in der Testzelle sofort zum Umbruch führen und die Ermittlung der Darstellungsbreite fehlschlägt
            test_cell.html(fullvalue);                                          // Test-DOM nowrapped mit voll dekoriertem Inhalt füllen
            test_cell.attr('class', 'slick-inner-cell '+column['cssClass']);    // Class ersetzen am Objekt durch aktuelle, dabei überschreiben evtl. vorheriger
            if (test_cell.prop("scrollWidth")  > column['max_nowrap_width']){
                column['max_nowrap_width']  = test_cell.prop("scrollWidth");
                thiz.slickgrid_render_needed = 1;
            }
            if (!column['no_wrap']  && test_cell.prop("scrollWidth") > column['max_wrap_width']){     // Nur Aufrufen, wenn max_wrap_width sich auch vergrößern kann (aktuelle Breite > bisher größte Wrap-Breite)
                test_cell_wrap.html(fullvalue);                                 // Test-DOM wrapped mit voll dekoriertem Inhalt füllen
                test_cell_wrap.attr('class', column['cssClass']);               // Class ersetzen am Objekt durch aktuelle, dabei überschreiben evtl. vorheriger


                if (test_cell_wrap.prop("scrollWidth")  > column['max_wrap_width']){
                    if (column['max_wrap_width_allowed'] && column['max_wrap_width_allowed'] < test_cell_wrap.prop("scrollWidth") )
                        column['max_wrap_width']  = column['max_wrap_width_allowed'];
                    else
                        column['max_wrap_width']  = test_cell_wrap.prop("scrollWidth");
                    thiz.slickgrid_render_needed = 1;
                }
                if (fullvalue != value)                                         // Enthält Zelle einen mit tags dekorierten Wert ?
                    test_cell_wrap.html("");                                    // leeren der Testzelle, wenn fullvalue weitere html-tags etc. enthält, ansonsten könnten z.B. Ziel-DOM-ID's mehrfach existierem
            }
            if (fullvalue != value)                                             // Enthält Zelle einen mit tags dekorierten Wert ?
                test_cell.html("");                                             // leeren der Testzelle, wenn fullvalue weitere html-tags etc. enthält, ansonsten könnten z.B. Ziel-DOM-ID's mehrfach existierem
            column['last_calc_value'] = value;                                  // Merken an Spalte für nächsten Vergleich
        }
    };

    /**
     * Ermittlung der Zeilenhöhe fuer einzeilige Darstellung
     * @returns {*}
     */
    function single_line_height() {
        return thiz.test_cell.html("1").prop("scrollHeight");
    }

} // Ende SlickGridExtended


// ############################# global functions ##############################

/**
 * Fangen des Resize-Events des Browsers und Anpassen der Breite aller slickGrids
 */
function resize_slickGrids(){
    jQuery('.slickgrid_top').each(function(index, element){
        var gridContainer = jQuery(element);
        if (gridContainer.data('last_resize_width') && gridContainer.data('last_resize_width') != gridContainer.parent().width() && gridContainer.data('slickgrid')) { // nur durchrechnen, wenn sich wirklich Breite ändert und grid bereits initialisiert ist
            // darf nur in Rekalkulation der Höhe laufen wenn sich Spaltenbreiten verändern
            // für vertikalen Resize muss Höhenberechnung übersprungen werden
            gridContainer.data('slickgridextended').calculate_current_grid_column_widths("resize_slickGrids");
            gridContainer.data('last_resize_width', gridContainer.parent().width());                       // persistieren Aktuelle Breite
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


function async_calc_all_cell_dimensions(slickGrid, start_row){
    var columns = slickGrid.grid.getColumns();
    var data    = slickGrid.grid.getData().getItems();

    var current_row = start_row;

    while (current_row < data.length && current_row < start_row+50){
        var rec = data[current_row];
        for (var col_index in columns){
            var column = columns[col_index];
            var column_metadata = rec['metadata']['columns'][column['field']];  // Metadata der Spalte der Row
            if (!column_metadata['dc'] || column_metadata['dc']==0) {            // bislang fand noch keine Messung der Dimensionen der Zellen dieser Zeile statt
                HTML_Formatter_prepare(slickGrid, current_row, col_index, rec[column['field']], column, rec, column_metadata);
            }
        }
        current_row++;
    }
    if (current_row < data.length){
        setTimeout(async_calc_all_cell_dimensions, 0, slickGrid, current_row);  // Erneut Aufruf einstellen für den Rest des Arrays
    } else {
        if (slickGrid.slickgrid_render_needed ==1){
            slickGrid.calculate_current_grid_column_widths('async_calc_all_cell_dimensions');
        }
    }
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

    if (!column_metadata['dc'] || column_metadata['dc']==0){                    // bislang fand noch keine Messung der Dimensionen der Zellen dieser Zeile statt
        slickGrid.calc_cell_dimensions(value, fullvalue, columnDef);            // Werte ermitteln und gegen bislang bekannte Werte der Spalte testen
        column_metadata['dc'] = 1;                                              // Zeile als berechnet markieren
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
        title += ". "+ slickGrid.printFloatLocale(pct_value, 2) + ' % ' + slickGrid.ext_locale_translate('slickgrid_pct_hint') + ' ' + slickGrid.printFloatLocale(columnDef['column_sum'], 0);
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
    if (style != "")
        output += " style='"+style+"'";
    output += ">"

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
};


/**
 * Übersetzungsliste
 *
 * @returns {string}
 */
function get_slickgrid_translations() {
    return {
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
            'de': 'Sortier-Methode für Spalten auf Bubble-Sort wechseln'
        },
        'slickgrid_context_menu_sort_method_BubbleSort': {
            'en': 'Switch column sort method to quick sort',
            'de': 'Sortier-Methode für Spalten auf Quick-Sort wechseln'
        },
        'slickgrid_context_menu_sort_method_QuickSort_hint': {
            'en': 'Switch column sort method to bubble sort.\nSorts slower but remains last sort order for equal values of current sort-column.\nAllows multi-column sort by subsequent sorting of columns',
            'de': 'Wechsel der Sortier-Methode auf Bubble-Sort.\nSortiert langsamer, aber erhält die vorherige Sortierfolge bei gleichen Werten der aktuellen Sortierspalte.\nErlaubt somit mehrspaltiges Sortieren durch aufeinanderfolgendes Klicken der zu sortierenden Spalten)'
        },
        'slickgrid_context_menu_sort_method_BubbleSort_hint': {
            'en': 'Switch column sort method to quick sort.\n Sorts faster but ignores previous sort order for equal values of current sort-column',
            'de': 'Wechsel der Sortier-Methode auf Quick-Sort.\nSortiert schnell, aber ignoriert die vorherige Sortierung bei gleichen Werten der aktuellen Sortierspalte'
        },
        'slickgrid_filter_hint_not_numeric': {
            'en': 'Filter by containing string',
            'de': 'Filtern nach enthaltener Zeichenkette'
        },
        'slickgrid_filter_hint_numeric': {
            'en': 'Filter by exact value (incl. thousands-delimiter and comma)',
            'de': 'Filtern nach exaktem Wert (incl. Tausender-Trennung und Komma)'
        },
        'slickgrid_pct_hint': {
            'en': 'of column sum',
            'de': 'der Spaltensumme von'
        }
    }
}









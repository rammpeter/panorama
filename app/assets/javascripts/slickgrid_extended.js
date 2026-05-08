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
class SlickGridExtended {
    constructor(container_id, options){
        this.container_id = container_id;
        this.options      = options;

        this._debug = new URLSearchParams(window.location.search).has('debug'); // Check if URL was something like https://myapp.com?debug to activate debug logging
        this._trace_log('SlickGridExtended: initializing with container_id='+container_id);

        this._scrollbarWidth_cache = null;                                      // cache for _scrollbarWidth
        this._columnFilters        = {};                                        // current filter criteria
        this.grid                  = null;                                      // SlickGrid object, set in initSlickGridExtended
        this.data_items            = null;

        this.gridContainer = jQuery('#'+container_id);
        this.gridContainer.addClass('slickgrid_top');
    } // Ende constructor

    /**
     * Parsen eines numerischen Wertes aus der landesspezifischen Darstellung mit Komma und Dezimaltrenner
     * @param value String-Darstellung
     * @returns float-value
     */
    parseFloatLocale(value){
        if (value === "")
            return 0;
        if (this.options['locale'] === 'en'){                                   // globale Option vom Aufrufer
            return parseFloat(value.replace(/,/g, ""));
        } else {
            return parseFloat(value.replace(/\./g, "").replace(/,/,"."));
        }
    }

    /**
     * Ausgabe eines numerischen Wertes in der landesspezifischen Darstellung mit Komma
     * @param {number} value Float-Wert
     * @param {number} precision Round by
     * @returns String-value
     */
    printFloatLocale(value, precision){
        var rounded_value = Math.round(value * Math.pow(10, precision)) / Math.pow(10, precision);
        if (this.options['locale'] === 'en'){                                   // globale Option vom Aufrufer
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
    getColumnByName(name){
        for (var col_index in this.all_columns) {
            var column = this.all_columns[col_index];
            if (column.name === name){
                return column;
            }
        }
        return null;                                                            // nichts gefunden
    }

    /**
     * Get width of parent element that controls maximum width of grid
     */
    get_grid_parent_width(){
        var grid_parent_width;
        if (this.gridContainer.parents().hasClass('flex-row-element'))
            grid_parent_width = this.gridContainer.parents('.flex-row-element').parent().prop('clientWidth');  // erstmal maximale Breit als Client annehmen, wird für auto-Breite später auf das notwendige reduziert
        else
            grid_parent_width = this.gridContainer.parent().prop('clientWidth');  // erstmal maximale Breit als Client annehmen, wird für auto-Breite später auf das notwendige reduziert
        return grid_parent_width;
    }

    // ###################### Private helper methods (promoted from constructor closures) #######################

    /**
     * Show log messages if URL was http://myapp?debug
     */
    _trace_log(message){
        if (this._debug){
            console.log(this.container_id + ": " + message);
        }
    }

    /**
     * Calculate width of a scrollbar (cached)
     */
    _scrollbarWidth(){
        if (this._scrollbarWidth_cache)
            return this._scrollbarWidth_cache;
        var div = $('<div style="width:50px;overflow-x:scroll;"><div id="scrollbarWidth_testdiv">Hugoplusadditionalinfo</div></div>');
        $('body').append(div);
        this._scrollbarWidth_cache = div.innerHeight() - div.find("#scrollbarWidth_testdiv").height();
        $(div).remove();
        this._trace_log("_scrollbarWidth: return value = "+this._scrollbarWidth_cache);
        return this._scrollbarWidth_cache;
    }

    /**
     * Get height of a single line in test cell
     */
    _single_line_height(){
        this.js_test_cell.innerHTML = '1';
        return this.js_test_cell.scrollHeight;
    }

    /**
     * Translate key into string according to options[:locale]
     */
    _locale_translate(key){
        var sl_locale = this.options['locale'];

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

    // ###################### Public methods (promoted from constructor closures) #######################

    /**
     * Helper zur Initialisierung des Objektes
     * @param container_id              ID of DOM-Container node to create the grid in.
     * @param data                      An array of objects for databinding.
     * @param columns                   An array of column definitions.
     * @param options                   Grid options.
     * @param additional_context_menu   Additional menu entries as object array
     */
    initSlickGridExtended(container_id, data, columns, options, additional_context_menu){
        var col_index;
        var column;
        this.all_columns = columns;                                             // Column-Deklaration in der Form wie dem SlickGrid übergeben inkl. hidden columns

        const viewable_columns = columns.filter(c => !c.hidden);

        this._init_test_cells();                                                // hidden DIV-Elemente fuer Groessentest aufbauen
        this._init_columns_and_calculate_header_column_width(viewable_columns, container_id);  // columns um Defaults und Weiten-Info der Header erweitern
        this._init_data(data, columns);                                         // data im fortlaufende id erweitern, auch für hidden columns
        this._init_options(options);                                            // Options um Defaults erweitern

        this.data_items = data;                                                 // direkt access to data structure
        var dataView = new Slick.Data.DataView();
        dataView.setItems(data);
        options["searchFilter"] = this._slickgrid_filter_item_row.bind(this);   // bind because SlickGrid calls it as bare function

        if (options['maxHeight']) {
            if (!jQuery.isNumeric(options['maxHeight'])) {                       // Expression set instead of numeric value for pixel
                options['maxHeight'] = eval(options['maxHeight']);              // execute expression to get height in px
            }
            options['maxHeight'] = Math.round(options['maxHeight']);            // Sicherstellen Ganzzahligkeit
        }

        options['rowHeight']     = 1;                                           // Default, der später nach Notwendigkeit größer gesetzt wird

        options['plotting']      = false;                                       // Soll Diagramm zeichenbar sein: Default=false wenn nicht eine Spalte als x-Achse deklariert ist
        for (col_index in viewable_columns) {
            column = viewable_columns[col_index];
            if (options['plotting'] && (column.plot_master || column.plot_master_time))
                alert('Only one column of table can be plot-master for x-axis!');
            if (column.plot_master || column.plot_master_time)
                options['plotting'] = true;

            if (column.show_pct_col_sum_hint || column.show_pct_col_sum_background){
                var column_sum = 0;
                for (var row_index in data){
                    column_sum += this.parseFloatLocale(data[row_index]['col'+col_index]);  // Kumulieren der Spaltensumme
                }
                column.column_sum = column_sum;
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
            .data('slickgridextended', this)
            .css('margin-top', '2px')
            .css('margin-bottom', '2px')
            .addClass('slick-shadow')
        ;

        // Grid durch Schieber am unteren Ende horizontal resizable gestalten
        this.gridContainer.resizable({
            stop: (event, ui) => {
                ui.element
                    .css('width', '')                                           // durch Resize gesetzte feste Weite wieder entfernen
                    .css('top', '')
                    .css('left', '')
                ;
                this._finish_vertical_resize();                                 // Sicherstellen, dass Höhe des Containers nicht größer als Höhe des Grids mit allen Zeilen sichtbar
            }
        });
        this.gridContainer.find(".ui-resizable-e").remove();                    // Entfernen des rechten resize-Cursors
        this.gridContainer.find(".ui-resizable-se").remove();                   // Entfernen des rechten unteren resize-Cursors

        this._initialize_slickgrid(this.grid);                                  // einmaliges Initialisieren des SlickGrid

        this._build_slickgrid_context_menu(container_id, additional_context_menu);  // Aufbau Context-Menu fuer Liste
    }

    // privileged function fuer Zugriff von aussen
    ext_locale_translate(key){ return this._locale_translate(key); }

    /**
     * Calculate height of header row
     */
    calculate_header_height(columns){
        // Hoehen von Header so setzen, dass der komplette Inhalt dargestellt wird
        var header_height = 1

        columns.forEach(column => {
            if (column.header_wrap_height > header_height){                     // Check only if max. height of header cell may increase options['headerHeight']
                this.js_test_cell_header_name.innerHTML = column.name;
                this.js_test_cell_header.style.width = (column.width-9)+'px';   // column width reduced by 2*padding=4 + 1*border=1
                if (this.js_test_cell_header.scrollHeight > header_height){
                    header_height = this.js_test_cell_header.scrollHeight;
                }
            }
        });
        header_height -= 4;
        this._trace_log('calculate_header_height: return value = ' + header_height);
        return header_height;                                               // reduced by padding-top because scrollheight counts inside padding
    }

    /**
     * Calculate row height
     */
    calculate_row_height(columns, options){
        const row_height_addition = 2;                                          // 1px border-top + 1px border-bottom  hinzurechnen
        var row_height = options['rowHeight']

        if (options["line_height_single"]){
            row_height = this._single_line_height() + 7;
        } else {                                                                // Volle notwendige Höhe errechnen
            // Hoehen von Cell so setzen, dass der komplette Inhalt dargestellt wird, aber wenigstens eine Zeile im Ganzen sichtbar bleibt

            // Ermitteln der max. Zeilen-Höhe für ganze Zeile im sichtbaren Bereich
            var max_visible_row_height = jQuery(window).height() / 3;           // 1/3 der sichtbare Browser-Hoehe
            if (options['maxHeight']) {
                max_visible_row_height = options['maxHeight'] / 3;
            }

            var slick_inner_cells = this.gridContainer.find(".slick-inner-cell");
            if (slick_inner_cells.length === 0){                                 // use fake div for first column instead of grid's cells
                var data = this.grid.getData().getItems();
                if (data.length > 0 ){                                          // at least one record in result
                    var rec = data[0];
                    this.grid.getColumns().forEach((column, _index) => {
                        // calculate decorated content of cell
                        var column_metadata = rec.metadata.columns[column.field];  // Metadata der Spalte der Row
                        var fullvalue = HTML_Formatter_prepare(this, 0, column.position, rec[column.field], column, rec, column_metadata);
                        //fullvalue =  fullvalue.replace(/<wbr>/g, '');                       // entfernen von vordefinierten Umbruchstellen, da diese in der Testzelle sofort zum Umbruch führen und die Ermittlung der Darstellungsbreite fehlschlägt
                        if (column.cssClass)
                            fullvalue = "<span class='" +column.cssClass+ "'>"+fullvalue+"</span>";
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
            slick_inner_cells.each(function(){                                  // Iteration über alle Zellen des Grid falls diese schon sichtbar sind  (this = jQuery iteration element, NOT class instance)
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
                    if (column.style) {
                        if (column.style.indexOf(new_css) !== -1) {
                            column.style = column.style+' '+new_css;
                        }

                    } else {                                                    // noch kein style definiert
                        column.style = new_css;
                    }
                }
            });
        }
        this._trace_log('calculate_row_height: return value = ' + row_height);
        return row_height;
    }

    /**
     * Fill unused space in column width until total width reaches current_grid_width
     */
    fill_unused_column_space(options, columns, current_table_width, current_grid_width){
        // Evtl. Zoomen der Spalten wenn noch mehr Platz rechts vorhanden
        if (options.width === '' || options.width === '100%'){                  // automatische volle Breite des Grid
            var wrapped_columns_remaining = true;                                // assume there are wrapped columns to enlarge at first
            var all_columns_fixed = true;                                       // assume there are no columns to expand
            // fill all columns one by one
            while (current_table_width < current_grid_width){                   // noch Platz am rechten Rand, kann auch nach wrap einer Spalte verbleiben
                var wrapped_column_found = false;
                columns.forEach(function(column) {
                    if (column.width < column.max_nowrap_width && !column.fixedWidth) // fixed colums could not be expanded
                        wrapped_column_found = true;                            // a wrapped column that should be expanded first
                    if (!column.fixedWidth)
                        all_columns_fixed = false;
                    if (current_table_width < current_grid_width && !column.fixedWidth &&
                        (!wrapped_columns_remaining || column.width < column.max_nowrap_width || column.width < column.header_nowrap_width )
                    ){
                        column.width++;
                        current_table_width++;
                    }
                });
                wrapped_columns_remaining = wrapped_column_found;                // enlarge all not fixed columns in next loops if no wrapped columns are remaining
            }
            if (all_columns_fixed && current_table_width < current_grid_width){ // if all columns are fixed, enlarge the last column
                columns[columns.length-1].width = columns[columns.length-1].width + current_grid_width - current_table_width;
                current_table_width = current_grid_width;
            }
        }
        return current_table_width;                                             // keep changed value for further user
    }

    /**
     * Berechnung der aktuell möglichen Spaltenbreiten in Abhängigkeit des Parent und anpassen slickGrid
     * Setzen / Löschen der Scrollbars je nach dem wie sie benötigt werden
     */
    calculate_current_grid_column_widths(caller){
        var options = this.grid.getOptions();
        var viewport_div = this.gridContainer.find('.slick-viewport.slick-viewport-top.slick-viewport-left');

        var current_grid_width = this.get_grid_parent_width();
        var columns = this.grid.getColumns();
        var max_table_width = 0;                                                // max. Summe aller Spaltenbreiten (komplett mit Scrollbereich)
        var h_padding       = 10;                                               // Horizontale Erweiterung der Spaltenbreite: padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)

        this._trace_log("calculate_current_grid_column_widths: start with caller = '"+ caller + "'");

        viewport_div.css('overflow', '');                                        // Default-Einstellung des SlickGrid für Scrollbar entfernen

        columns.forEach(function(column){
            column.width = column.fixedWidth ? column.fixedWidth : column.max_nowrap_width+h_padding; // per Default komplette Breite des Inhaltes als Spaltenbreite annehmen , Korrektur um padding-right(2) + padding-left(2) + border-left(1) + Karrenz(1)
            max_table_width += column.width;
        });

        var current_table_width = max_table_width + this._scrollbarWidth();     // Assume vertical scrollbar is needed, fixed later if no vertical scrollbar

        // Check for possible wrap in column to reduce width of grid
        var more_wrap_possible = true;                                          // Assume more wraps are possible
        while (current_table_width > current_grid_width && more_wrap_possible) {    // until target width reached or no more reduction possible
            more_wrap_possible = false;                                         // Assume no wrap is possible until column states the opposite
            columns.forEach(function(column){
                if (   current_table_width > current_grid_width                         // Verkleinerung der Breite notwendig?
                    && column.width     > column.max_wrap_width+h_padding         // diese spalte könnte verkleinert werden
                    && !column.fixedWidth
                    && !column.no_wrap
                ) {
                    column.width--;
                    current_table_width--;
                    if (column.width > column.max_wrap_width+h_padding)   // more wrapping is possible in next loop
                        more_wrap_possible = true;
                }
            });
        }

        current_table_width = this.fill_unused_column_space(options, columns, current_table_width, current_grid_width);   // Enlarge columns up to current_grid_width if possible

        var needs_horizontal_scrollbar = current_table_width-this._scrollbarWidth() > current_grid_width - 1;
        this._trace_log("calculate_current_grid_column_widths: caller = '" + caller+ "' needs_horizontal_scrollbar = "+ needs_horizontal_scrollbar);

        var row_height = this.calculate_row_height(columns, options);       // get row height based on previously set column width

        options['headerHeight'] = this.calculate_header_height(columns);

        var total_height = options['headerHeight']                          // innere Höhe eines Headers
            + 8                                                             // padding top und bottom=4 des Headers
            + 2                                                             // border=1 top und bottom des headers
            + (row_height * this.grid.getDataLength() )                     // Höhe aller Datenzeilen
            + (needs_horizontal_scrollbar ? this._scrollbarWidth() : 0)
            + (options["showHeaderRow"] ? options["headerRowHeight"] : 0)
            + 1                                                             // Karrenz wegen evtl. Rundungsfehler
        ;

        var total_scroll_height = total_height;                                 // Wirkliche sichtbare Höhe
        if (options['maxHeight'] && options['maxHeight'] < total_height)
            total_scroll_height = options['maxHeight'];                         // Limitieren der Höhe auf Vorgabe wenn sonst überschritten

        var needs_vertical_scrollbar = total_scroll_height < total_height;
        this._trace_log("calculate_current_grid_column_widths: caller = '" + caller+"' needs_vertical_scrollbar = "+ needs_vertical_scrollbar);

        if (!needs_vertical_scrollbar)                                          // use unused space for vertical scrollbar for columns
            current_table_width = this.fill_unused_column_space(options, columns, current_table_width-this._scrollbarWidth(), current_grid_width);


        this.gridContainer.data('last_resize_width', this.get_grid_parent_width()); // Merken der aktuellen Breite des Parents, um unnötige resize-Events zu vermeiden

        if (options['width'] === "auto"){
            var vertical_scrollbar_width = needs_vertical_scrollbar ? this._scrollbarWidth() : 0;
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

        const trace_log_inner = (msg) => this._trace_log(msg);
        columns.forEach(function(column) {
            trace_log_inner("calculate_current_grid_column_widths: " + column.name+ ': width='+column.width);
        });
        this._trace_log("calculate_current_grid_column_widths: caller = '"+ caller+"' end");
    }

    /**
     * Ein- / Ausblenden der Filter-Inputs in Header-Rows des Slickgrids
     */
    switch_slickgrid_filter_row(){
        var options = this.grid.getOptions();
        if (options["showHeaderRow"]) {
            this.grid.setHeaderRowVisibility(false);
            this.grid.getData().setFilter(options["data_filter"]);              // Ruecksetzen auf externen data_filter falls gesetzt, sonst null
        } else {
            this.grid.setHeaderRowVisibility(true);
            this.grid.getData().setFilter(options["searchFilter"]);
        }
        this.grid.setColumns(this.grid.getColumns());                                     // Auslösen/Provozieren des Events onHeaderRowCellRendered für slickGrid
        this.calculate_current_grid_column_widths("switch_slickgrid_filter_row");  // Höhe neu berechnen
    }

    /**
     * Speichern Inhalt und Erneutes Berechnen der Breite und Höhe einer Zelle nach Änderung ihres Inhaltes
     */
    save_new_cell_content(obj){
        var inner_cell = obj.parents(".slick-inner-cell");
        var column = null;
        for (var column_index in this.grid.getColumns()){
            if (this.grid.getColumns()[column_index]['field'] === inner_cell.attr('column'))
                column = this.grid.getColumns()[column_index];
        }
        // Rückschreiben des neuen Dateninhaltes in Metadata-Struktur des Grid
        this.grid.getData().getItems()[inner_cell.attr("row")][inner_cell.attr("column")] = inner_cell.text();  // sichtbarer Anteil der Zelle
        this.grid.getData().getItems()[inner_cell.attr("row")]["metadata"]["columns"][inner_cell.attr("column")]["fulldata"] = inner_cell.html(); // Voller html-Inhalt der Zelle

        this.calc_cell_dimensions(inner_cell.html(), column);     // Neu-Berechnen der max. Größen durch getürkten Aufruf der Zeichenfunktion
        this.calculate_current_grid_column_widths('recalculate_cell_dimension'); // Neuberechnung der Zeilenhöhe, Spaltenbreite etc. auslösen
    }

    /**
     * Callback aus plot_diagram wenn eine Kurve entfernt wurde, denn plottable der Spalte auf 0 drehen
     */
    plot_chart_delete_callback(legend_label){
        var columns = this.grid.getColumns();
        for (var column_index in columns) {
            if (columns[column_index]['name'] === legend_label) {
                columns[column_index]['plottable'] = 0;                         // diese Spalte beim nächsten plot_diagram nicht mehr mit zeichnen
            }
        }
    }

    /**
     * Berechnen der Dimensionen einer konkreten Zelle, native Javascript instead of jQuery because it's heavy frequented
     */
    calc_cell_dimensions(test_html, column){
        var js_test_cell        = this.js_test_cell;
        var js_test_cell_wrap   = this.js_test_cell_wrap;

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
            js_test_cell_wrap.innerHTML = '';                           // leeren der Testzelle
        }
        js_test_cell.innerHTML = '';                                    // leeren der Testzelle
    }

    /**
     * Pin all elements of grid (move grid to another new parent to prevent it from being overwritten by parent reload)
     */
    pin_grid(pin_at_toplevel){
        if (!this.options['top_level_container_id']){
            throw "Value for SlickGridExtended-option 'top_level_container_id' ist needed to process pin_grid"
        }

        if (this.options['update_area']){
            jQuery('#'+ this.options['update_area']).children().remove();
        }

        var grid_parent = this.gridContainer.parent();

        let target_for_pinned;
        let pin_button_outer_span;
        let new_title;

        if (pin_at_toplevel){
            target_for_pinned = jQuery('#'+this.options['top_level_container_id']);
            pin_button_outer_span = jQuery('#'+this.container_id+'_header_left_box_pin_grid_global');
            new_title = this._locale_translate('slickgrid_pinned_global_hint');
            jQuery('#'+this.container_id+'_header_left_box_pin_grid_local').css('display', 'none');      // hide local pin button if global was hit
            pin_button_outer_span.css('background-color', 'lightgray');         // mark pin button special as global pin
        } else {
            target_for_pinned = grid_parent;
            pin_button_outer_span = jQuery('#'+this.container_id+'_header_left_box_pin_grid_local');
            new_title = this._locale_translate('slickgrid_pinned_local_hint');
            jQuery('#'+this.container_id+'_header_left_box_pin_grid_global').css('display', 'inline');      // show global pin button after local pin

            for (let i = 1; i < this.options['show_pin_icon']; i++) {                // step up for parents according to number of parent_tree_depth
                target_for_pinned = target_for_pinned.parent();
            }
            if (target_for_pinned.attr('id') === this.options['top_level_container_id']){
                this.pin_grid(true);                                            // treat as top level pin if called from directly from first page after menu action
                return;
            }
        }

        var new_parent = jQuery('<div id="pinned_container_'+this.container_id+'"></div>').insertBefore(target_for_pinned);
        new_parent.append(grid_parent.children());                                  // move all elements of grid's parent to new paren

        var pin_button_span = pin_button_outer_span.find('.cui-pin');
        pin_button_span.removeClass('cui-pin');
        pin_button_span.addClass('cuis-pin');
        pin_button_span.parent()
            .attr('title', new_title)
            .css('cursor', 'default')
            .attr('onclick', null)
        ;

        // set new title for close button: closes also descendants
        jQuery('#'+this.container_id+'_header_left_box_remove_table_from_page').attr('title', this._locale_translate('slickgrid_close_descendants_hint'));

        this.pinned = true;                                                     // remember pinned-status for close-handling
    }

    remove_grid(){
        if (this.pinned){                                                       // remove whole parent div including descendants of grid
            jQuery('#'+this.container_id).parent().remove();
        } else {                                                                // remove detailed elements of grid from parent
            jQuery('#caption_'+this.container_id).remove();
            jQuery('#'+this.container_id).remove();
            jQuery('#menu_'+this.container_id).remove();
        }
    }

    // ###################### Promoted inner helper methods #######################

    /**
     * Aufbau der Zellen zur Ermittlung Höhe und Breite
     */
    _init_test_cells(){
        const container_id = this.container_id;
        var test_cell_id                = 'test_cell'               +container_id;
        var test_cell_wrap_id           = 'test_cell_wrap'          +container_id;
        var test_cell_height_id         = 'test_cell_height'        +container_id;
        var test_cell_header_id         = 'test_cell_header'        +container_id;
        var test_cell_header_name_id    = 'test_cell_header_name'   +container_id;
        var test_cells_outer = jQuery(
            '<div>'+
            '<div class="slick-inner-cell" style="visibility:hidden; position:absolute; left: 0; z-index: -1; padding: 0; margin: 0; height: 20px; width: 90%;"><nobr><div id="' + test_cell_id + '" style="width: 1px; height: 1px; overflow: hidden;"></div></nobr></div>'+
            '<div  class="slick-inner-cell" id="' + test_cell_wrap_id + '" style="visibility:hidden; position:absolute; left: 0; z-index: -1; width:1px; height:'+jQuery(window).height()/2+'px; padding: 0; margin: 0; word-wrap: normal;"></div>' +
            '</div>'+
            '<div  class="slick-inner-cell" id="' + test_cell_height_id + '" style="visibility:hidden; position:absolute; left: 0; z-index: -1; height:1px; padding: 0; margin: 0; word-wrap: normal;"></div>' +
            '</div>'+
            '<div id="'+test_cell_header_id+'" class="ui-state-default slick-header-column slick-header-sortable"   style="visibility:hidden; position:absolute; left: 0; z-index: -1; width:1px; height: 1px; margin: 0; word-wrap: normal;">'+
            '  <span class="slick-column-name" id="'+ test_cell_header_name_id +'"></span>' +
            '  <span class="slick-sort-indicator"></span>' +
            '</div>'
        );

        this.gridContainer.after(test_cells_outer);
        this.js_test_cell               = document.getElementById(test_cell_id);
        this.js_test_cell_wrap          = document.getElementById(test_cell_wrap_id);
        this.js_test_cell_height        = document.getElementById(test_cell_height_id);
        this.js_test_cell_header        = document.getElementById(test_cell_header_id);
        this.js_test_cell_header_name   = document.getElementById(test_cell_header_name_id);
    }

    /**
     * data im fortlaufende id erweitern
     */
    _init_data(data, columns){
        for (var data_index in data){
            var data_row = data[data_index];
            data_row['id'] = data_index;
            if (!data[data_index]['metadata'])
                data[data_index]['metadata'] = {columns: {}};
            columns.filter(c => !data_row['metadata']['columns'][c.field]).forEach(col => {
                data_row['metadata']['columns'][col.field] = {};
            });
        }
    }

    /**
     * Ermittlung Spaltenbreite der Header auf Basis der konkreten Inhalte
     */
    _init_columns_and_calculate_header_column_width(columns, container_id){
        function init_column(column, key, value){
            if (!column[key])
                column[key] = value;
        }

        var column;
        for (var col_index in columns){
            column = columns[col_index];

            init_column(column, 'formatter',    HTMLFormatter);
            init_column(column, 'sortable',     true);
            init_column(column, 'sort_type',    'string');
            init_column(column, 'field',        column.id);
            init_column(column, 'minWidth',     5);
            init_column(column, 'headerCssClass', 'slickgrid_header_'+container_id);
            init_column(column, 'slickgridExtended', this);
            init_column(column, 'position',     col_index);

            this.js_test_cell_header.style.width = '';
            this.js_test_cell_header_name.innerHTML = column.name;
            column.header_nowrap_width  = this.js_test_cell_header.scrollWidth;

            this.js_test_cell_header.style.width = '1px';
            column.max_wrap_width      = this.js_test_cell_header.scrollWidth-10;
            column.header_wrap_height  = this.js_test_cell_header.scrollHeight;

            column.max_nowrap_width    = column.max_wrap_width;
        }
    }

    /**
     * Options um Defaults erweitern
     */
    _init_options(options){
        function init_option(key, value){
            if (!options[key])
                options[key] = value;
        }

        init_option('enableCellNavigation', true);
        init_option('headerRowHeight',      30);
        init_option('enableColumnReorder',  false);
        init_option('width',                'auto');
        init_option('locale',               'en');
        init_option('sort_method',          'QuickSort');
    }

    /**
     * Calculate column-specific attributes for xy-position of event
     */
    _set_column_attributes_for_event(container_id, event){
        var cell = $(event.target);
        this.last_slickgrid_contexmenu_col_header = null;

        if (cell.parents(".slickgrid_header_"+container_id).length > 0){
            cell = cell.parents(".slickgrid_header_"+container_id);
        }
        if (cell.hasClass("slickgrid_header_"+container_id)){
            this.last_slickgrid_contexmenu_col_header = cell;
            this.last_slickgrid_contexmenu_column_name = cell.data('column')['field']
        }
        if (cell.parents(".slick-cell").length > 0){
            cell = cell.parents(".slick-cell");
        }
        if (cell.hasClass("slick-cell")){
            var slick_header = this.gridContainer.find('.slick-header-columns');
            cell = cell.find(".slick-inner-cell");
            this.last_slickgrid_contexmenu_col_header = slick_header.children('[id$=\"'+cell.attr('column')+'\"]');
            this.last_slickgrid_contexmenu_column_name = cell.attr('column');
            this.last_slickgrid_contexmenu_field_content = cell.text();
        }
    }

    /**
     * Filtern einer Zeile des Grids gegen aktuelle Filter
     */
    _slickgrid_filter_item_row(item){
        for (var columnId in this._columnFilters) {
            if (columnId !== undefined && this._columnFilters[columnId] !== "") {
                var c = this.grid.getColumns()[this.grid.getColumnIndex(columnId)];
                if (c.sort_type === "float" &&  item[c.field] !== this._columnFilters[columnId]) {
                    return false;
                }
                if (c.sort_type !== "float" &&  (item[c.field].toUpperCase().match(this._columnFilters[columnId].toUpperCase())) == null ) {
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * Anzeige des kompletten Inhaltes der Zelle
     */
    _show_full_cell_content(content, title=''){
        var wrapped = jQuery("<div>" + content + "</div>");
        wrapped.find("a").replaceWith(function() { return jQuery(this).html(); });
        content = wrapped.html();

        var div_id = 'slickgrid_extended_alert_box';
        if (!jQuery('#'+div_id).length){
            jQuery('body').append('<div id="'+div_id+'"></div>');
        }
        jQuery("#"+div_id)
            .html(content)
            .dialog({
                    title:      title,
                    draggable:  true,
                    width:      jQuery(window).width()*0.5,
                    maxHeight:  jQuery(window).height()*0.9,
                    beforeClose:function(){jQuery('#'+div_id).children().remove(); }
            })
        ;
    }

    /**
     * Statistik aller Zeilen der Spalte
     */
    _show_column_stats(column_name){
        var column          = this.grid.getColumns()[this.grid.getColumnIndex(column_name)];
        var data            = this.grid.getData().getItems();
        var sum             = 0;
        var average         = null;
        var count           = 0;
        var distinct        = {};
        var distinct_count  = 0;
        for (var row_index in data){
            sum += this.parseFloatLocale(data[row_index][column_name]);
            count ++;
            distinct[data[row_index][column_name]] = 1;
        }
        for (var i in distinct) {
            distinct_count += 1;
        }

        if (count > 0)
            average = sum/count;
        this._show_full_cell_content("Sum = "+sum+"<br/>Average = "+average+"<br/>Count = "+count+"<br/>Count distinct = "+distinct_count, 'Column: '+column.name);
    }

    /**
     * Setzen/Limitieren der Höhe des Grids auf maximale Höhe des Inhaltes
     */
    _adjust_real_grid_height(){
        var total_height = this.gridContainer.data('total_height');
        if (total_height < this.gridContainer.height())
            this.gridContainer.height(total_height);
    }

    /**
     * Justieren des Grids nach Abschluss der Resize-Operation mit unterem Schieber
     */
    _finish_vertical_resize(){
        var options = this.grid.getOptions();
        options['maxHeight'] = this.gridContainer.height();
        this.grid.setOptions(options);

        this.calculate_current_grid_column_widths('finish_vertical_resize');
        this._adjust_real_grid_height();
    }

    /**
     * Event-handler if column has been resized
     */
    _processColumnsResized(grid){
        this._trace_log("processColumnsResized: called");
        for (var col_index in grid.getColumns()){
            var column = grid.getColumns()[col_index];
            if (Math.round(column.previousWidth) !== Math.round(column.width)){
                column.fixedWidth = column.width;
            }
        }
        this.calculate_current_grid_column_widths("processColumnsResized");
    }

    /**
     * Zeichnen eines Diagrammes mit den Daten einer slickgrid-Spalte
     */
    _plot_slickgrid_diagram(table_id, plot_area_id, caption, column_id, multiple_y_axes, show_y_axes){
        const self = this;
        var options = self.grid.getOptions();
        var columns = self.grid.getColumns();
        var data    = self.grid.getData().getItems();

        function get_numeric_content(celldata){
            if (celldata === '')
                return 0;
            if (options['locale'] === 'de'){
                return parseFloat(celldata.replace(/\./g, "").replace(/,/,"."));
            }
            if (options['locale'] === 'en'){
                return parseFloat(celldata.replace(/,/g, ""));
            }
            return "Error: unsupported locale "+options['locale'];
        }

        function get_date_content(celldata){
            var parsed_field;
            if (options['locale'] === 'de'){
                var all_parts = celldata.split(" ");
                var date_parts = all_parts[0].split(".");
                parsed_field = date_parts[2]+"/"+date_parts[1]+"/"+date_parts[0]+" "+all_parts[1];
            }
            if (options['locale'] === 'en'){
                parsed_field= celldata.replace(/-/g,"/").replace(/‑/g, "/");
            }
            return new Date(parsed_field+" GMT");
        }

        function data_array_sort(a,b){
            return a[0] - b[0];
        }

        columns.forEach((column, _col_index) => {
            if (column.id === column_id){
                if (column.plottable === 1)
                    column.plottable = 0;
                else
                    column.plottable = 1
            }
        });

        var plot_master_column_index = null;
        var plot_master_column_id = null;
        var plot_master_time_column_index=null;
        var plotting_column_count = 0;
        for (let column_index in columns) {
            let column = columns[column_index];
            if (column.plot_master){
                if (plot_master_column_index){ alert("Only one column may have attribute 'plot_master'");}
                plot_master_column_index = column_index;
                plot_master_column_id = column.id;
            }
            if (column.plot_master_time){
                if (plot_master_time_column_index){ alert("Only one column may have attribute 'plot_master_time'");}
                plot_master_column_index = column_index;
                plot_master_column_id = column.id;
                plot_master_time_column_index=column_index;
            }
            if (column.plottable === 1){
                plotting_column_count++;
            }
        }
        if (plot_master_column_index == null){
            alert('Error: No <th>-column has class "plot_master"! Exactly one column of this class is expected!');
        }

        var x_axis_time = false;
        var data_array = [];
        var plotting_index = 0;
        var smallest_y_value = 0;
        for (let column_index in columns) {
            let column = columns[column_index];
            if (column.plottable===1){
                var col_data_array = [];
                var max_column_value = 0;
                for (var data_index in data){
                    var x_val = null;
                    var y_val = null;
                    y_val = get_numeric_content(data[data_index][column.id]);
                    if (y_val > max_column_value)
                        max_column_value = y_val;
                    if (y_val < smallest_y_value)
                        smallest_y_value = y_val;
                    if (plot_master_time_column_index){
                        x_val = get_date_content(data[data_index][plot_master_column_id]).getTime();
                        x_axis_time = true;
                    } else {
                        x_val = get_numeric_content(data[data_index][plot_master_column_id]);
                    }
                    col_data_array.push( [ x_val, y_val ]);
                }
                col_data_array.sort(data_array_sort);
                var col_attr = {label:column.name,
                    delete_callback: self.plot_chart_delete_callback,
                    data: col_data_array
                };
                data_array.push(col_attr);
                plotting_index = plotting_index + 1;
            }
        }

        var yaxis_options = { show: show_y_axes };
        if (smallest_y_value === 0)
            yaxis_options.min = 0;

        plot_diagram(
            table_id,
            plot_area_id,
            caption,
            data_array,
            {   plot_diagram: { locale: options['locale'], multiple_y_axes: multiple_y_axes},
                yaxis:        yaxis_options,
                xaxes: (x_axis_time ? [{ mode: 'time'}] : [{}])
            }
        );
    }

    /**
     * Create context-Menu für slickgrid
     */
    /**
     * initialer Aufbau des SlickGrid-Objektes
     */
    _initialize_slickgrid(grid){
        const self = this;
        const options = self.options;
        const container_id = self.container_id;
        var dataView = grid.getData();

        grid.onSort.subscribe(function(e, args) {
            var col = args.sortCol;
            var field = col.field;

            function convert_german_date(value){
                var tag_zeit = value.split(" ");
                var dat = tag_zeit[0].split(".");
                return dat[2]+dat[1]+dat[0]+(tag_zeit[1] ? tag_zeit[1] : "");
            }

            function quickSort(){
                var sortFunc = function(a,b){
                    if (a[field] < b[field])
                        return -1;
                    if (a[field] > b[field])
                        return 1;
                    if (a[field] === b[field])
                        return 0;
                };

                if (col['sort_type'] === "float") {
                    sortFunc  = function(a, b) {
                        return self.parseFloatLocale(a[field]) - self.parseFloatLocale(b[field]);
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

            function bubbleSort(){
                var data_array = dataView.getItems();

                var sort_smaller = function(value1, value2){return value1<value2;};

                if (col['sort_type'] === "float"){
                    sort_smaller = function(value1, value2){
                        return self.parseFloatLocale(value1) < self.parseFloatLocale(value2);
                    }
                }

                if (col['sort_type'] === "date" && options['locale'] === 'de'){
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
                alert('Option "sort_method" with unsupported value "'+grid.getOptions()['sort_type']+'"');
            }

            if (!args.sortAsc)
                dataView.getItems().reverse();
            dataView.refresh();
            grid.invalidate();
            grid.render();
        });

        grid.onHeaderCellRendered.subscribe(function(node, column){
            jQuery(column.node).css('height', column.grid.getOptions()['headerHeight']);
        });

        grid.onColumnsResized.subscribe(function(){
            self._processColumnsResized(this);
        });

        dataView.onRowCountChanged.subscribe(function (_e, _args) {
            grid.updateRowCount();
            grid.render();
        });

        dataView.onRowsChanged.subscribe(function (e, args) {
            grid.invalidateRows(args.rows);
            grid.render();
        });

        $(grid.getHeaderRow()).on("input", ":input",  function (_e) {
            var columnId = $(this).data("columnId");                            // this = jQuery input element, NOT class instance
            if (columnId != null) {
                self._columnFilters[columnId] = $.trim($(this).val());
                dataView.refresh();
            }
        });

        grid.onHeaderRowCellRendered.subscribe(function(e, args) {

            function input_hint(column_id){
                if (grid.getColumns()[grid.getColumnIndex(column_id)].sort_type === "float" )
                    return self._locale_translate("slickgrid_filter_hint_numeric");
                else
                    return self._locale_translate("slickgrid_filter_hint_not_numeric");
            }

            $(args.node).empty();
            $("<input type='text' style='font-size: 12px; width: 100%;' title='"+input_hint(args.column.id)+"'>")
                .data("columnId", args.column.id)
                .val(self._columnFilters[args.column.id])
                .appendTo(args.node);
        });

        grid.onDblClick.subscribe(function(e, args){
            self._show_full_cell_content(jQuery(grid.getCellNode(args['row'], args['cell'])).children().html());
        });

        if (options['caption'] && options['caption'] !== ""){
            let caption = jQuery("<div id='caption_"+container_id+"' class='slick-caption slick-shadow'></div>").insertBefore('#'+container_id);

            let caption_left_box  = jQuery("<span class='slick_header_left_box'></span>");
            let caption_right_box = jQuery("<span class='slick_header_right_box'></span>");
            caption.append(caption_left_box);
            caption.append('<span class="slick_header_middle_box">'+options['caption']+'</span>');
            caption.append(caption_right_box);

            if (!options['command_menu_entries']){
                options['command_menu_entries'] = [];
            }

            options['command_menu_entries'].reverse();
            options['command_menu_entries'].push({
                name:                   'toggle_search_filter',
                caption:                self._locale_translate("slickgrid_context_menu_search_filter"),
                hint:                   self._locale_translate("slickgrid_context_menu_search_filter_hint"),
                icon_class: 'cui-magnifying-glass',
                show_icon_in_caption:   'only',
                action:                 "jQuery('#"+container_id+"').data('slickgridextended').switch_slickgrid_filter_row();"
            });
            options['command_menu_entries'].reverse();


            if (options['show_pin_icon']){
                options['command_menu_entries'].push({
                    name:                  'pin_grid_global',
                    caption:                'Pin table',
                    hint:                   self._locale_translate('slickgrid_pin_global_hint'),
                    icon_class:             'cui-pin',
                    show_icon_in_caption:   'right',
                    action:                 "jQuery('#"+container_id+"').data('slickgridextended').pin_grid(true);",
                    unvisible:              true
                });
                options['command_menu_entries'].push({
                    name:                  'pin_grid_local',
                    caption:                'Pin table',
                    hint:                   self._locale_translate('slickgrid_pin_local_hint'),
                    icon_class:             'cui-pin',
                    show_icon_in_caption:   'right',
                    action:                 "jQuery('#"+container_id+"').data('slickgridextended').pin_grid(false);"
                });
            }

            options['command_menu_entries'].push({
                name:                   'remove_table_from_page',
                caption:                'Close table',
                hint:                   self._locale_translate('slickgrid_close_hint'),
                icon_class:             'cui-x',
                show_icon_in_caption:   'right',
                action:                 "jQuery('#"+container_id+"').data('slickgridextended').remove_grid();"
            });


            let show_command_entry_menu = false;
            for (let cmd_index in options['command_menu_entries']) {
                let cmd = options['command_menu_entries'][cmd_index];
                if (cmd['show_icon_in_caption'] !== 'only' && cmd['show_icon_in_caption'] !== 'right'){
                    show_command_entry_menu = true;
                }
            }

            if (show_command_entry_menu) {
                let command_menu_id = 'cmd_menu_'+container_id;

                caption_left_box.append('<div style="margin-left:5px; margin-right:5px; display: inline-block;" class="slick-shadow">' +
                    '<div id="'+command_menu_id+'" style="padding-left: 10px; padding-right: 10px; background-color: #E0E0E0; cursor: pointer;" title="'+self._locale_translate('slickgrid_menu_hint')+'">' +
                    '≡' +
                    '</div></div>'
                );
                jQuery("#"+command_menu_id).bind('click' , function( event) {
                    jQuery("#"+command_menu_id).trigger("contextmenu", event);
                    return false;
                });

                jQuery('#' + command_menu_id).parent().contextMenu({
                    selector: 'div',
                    build: function ($trigger, _e) {
                        let command_menu_items = {};

                        function create_command_menu_entries(local_items, entry_array){
                            for (let entry_index in entry_array){
                                let entry = entry_array[entry_index];
                                if (entry.show_icon_in_caption !== 'only' && entry.show_icon_in_caption !== 'right') {
                                    let new_item = {
                                        name: "<span class='"+entry.icon_class+"' style='float:left'></span><span title='"+entry.hint+ "'>&nbsp;"+entry.caption+"</span>",
                                        isHtmlName: true,
                                    };
                                    if (entry.items !== undefined){
                                        let submenu_items = {};
                                        create_command_menu_entries(submenu_items, entry.items);
                                        new_item.items = submenu_items;
                                    } else {
                                        new_item.callback = new Function(entry.action);
                                    }
                                    local_items[entry.caption] = new_item;
                                }
                            }
                        }
                        create_command_menu_entries(command_menu_items, options.command_menu_entries);

                        return { items: command_menu_items };
                    }
                });
            }

            for (let cmd_index in options['command_menu_entries']) {
                let cmd = options['command_menu_entries'][cmd_index];
                if (cmd['show_icon_in_caption'] && cmd['show_icon_in_caption'] !== 'right' ){
                    caption_left_box.append('<div style="margin-left:5px; margin-top:4px; cursor: pointer; display: inline-block;" '+
                        'title="'+cmd['hint'] + '" onclick="'+ cmd['action'] +'">' +
                        '<span class="'+cmd['icon_class']+'"></span>' +
                        '</div>');
                }
            }


            for (let cmd_index in options['command_menu_entries']) {
                let cmd = options['command_menu_entries'][cmd_index];
                if (cmd['show_icon_in_caption'] === 'right' ){
                    caption_right_box.append('<span id="'+container_id+'_header_left_box_'+cmd['name']+'"'+
                        ' style="margin-right:3px; margin-top:4px; cursor: pointer;'+((cmd['unvisible']) ? 'display: none;' : '')+'"'+
                        ' title="'+cmd['hint'] + '" onclick="'+ cmd['action'] +'">' +
                        '<span class="'+cmd['icon_class']+'"></span>' +
                        '</span>');
                }
            }
        }

        dataView.setFilter(options["data_filter"]);
    }

    _build_slickgrid_context_menu(container_id, additional_menu_entries){
        const self = this;
        jQuery('#'+container_id).contextMenu({
            selector: 'div',
            build: function($trigger, e) {
                let options = self.grid.getOptions();
                self._set_column_attributes_for_event(container_id, e);

                let header_line;
                if (self.last_slickgrid_contexmenu_col_header) {
                    header_line = 'Column: <b>'+self.last_slickgrid_contexmenu_col_header.text()+'</b>';
                } else {
                    header_line = '<span style="background-color: red; color: black;">&nbsp;Column/cell not exactly hit! Please retry.&nbsp;</span>';
                }
                let items = {
                    header: {
                        name: header_line,
                        isHtmlName: true,
                        disabled: true
                    },
                };

                function add_item_to_context_menu(items, label, icon_class, click_action, hint){
                    items[label] = {
                        name: "<span class='"+icon_class+"' style='float:left'></span><span title='"+hint+ "'>&nbsp;"+label+"</span>",
                        isHtmlName: true,
                        callback: click_action,
                    };
                }

                function add_default_item_to_context_menu(name, icon_class, click_action){
                    add_item_to_context_menu(items, self._locale_translate("slickgrid_context_menu_"+name), icon_class, click_action, self._locale_translate("slickgrid_context_menu_"+name+"_hint"));
                }

                add_default_item_to_context_menu("sort_column", 'cui-sort-ascending', function(){ self.last_slickgrid_contexmenu_col_header.click();} );
                if (self.grid.getOptions().showHeaderRow) {
                    add_default_item_to_context_menu("hide_filter", 'cui-magnifying-glass', function(){ self.switch_slickgrid_filter_row();} );
                } else {
                    add_default_item_to_context_menu("show_filter", 'cui-magnifying-glass', function(){ self.switch_slickgrid_filter_row();} );
                }
                add_default_item_to_context_menu("export_csv", 'cui-file-xls', function(){ self._grid2CSV(container_id);} );
                add_default_item_to_context_menu("column_sum", 'cui-settings', function(){ self._show_column_stats(self.last_slickgrid_contexmenu_column_name);} );
                add_default_item_to_context_menu("field_content", 'cui-zoom-in', function(){ self._show_full_cell_content(self.last_slickgrid_contexmenu_field_content);} );

                if (options.line_height_single)
                    add_default_item_to_context_menu("line_height_full", 'cui-text-height', function(){ options.line_height_single = !options.line_height_single; self.calculate_current_grid_column_widths("context menu line_height_single"); } );
                else
                    add_default_item_to_context_menu("line_height_single", 'cui-text-height', function(){ options.line_height_single = !options.line_height_single; self.calculate_current_grid_column_widths("context menu line_height_single"); } );

                if (options['plotting']){
                    if (self.last_slickgrid_contexmenu_col_header) {
                        let column = self.grid.getColumns()[self.grid.getColumnIndex(self.last_slickgrid_contexmenu_column_name)];
                        if (column.plottable) {
                            add_default_item_to_context_menu("switch_col_from_diagram", 'cui-chart-line', function(){
                                self._plot_slickgrid_diagram(container_id, options.plot_area_id, options.caption, self.last_slickgrid_contexmenu_column_name, options.multiple_y_axes, options.show_y_axes);
                            });
                        } else {
                            add_default_item_to_context_menu("switch_col_into_diagram", 'cui-chart-line', function(){
                                self._plot_slickgrid_diagram(container_id, options.plot_area_id, options.caption, self.last_slickgrid_contexmenu_column_name, options.multiple_y_axes, options.show_y_axes);
                            });
                        }
                    }

                    add_default_item_to_context_menu("remove_all_from_diagram", 'cui-trash', function(){
                        let columns = self.grid.getColumns();
                        for (let col_index in columns){
                            columns[col_index].plottable = 0;
                        }
                        self._plot_slickgrid_diagram(container_id, options.plot_area_id, options.caption, null);
                    });
                }

                if (options['sort_method'] === 'QuickSort'){
                    add_default_item_to_context_menu("sort_method_QuickSort", 'cui-calculator', function(){ options.sort_method = 'BubbleSort'; } );
                } else {
                    add_default_item_to_context_menu("sort_method_BubbleSort", 'cui-calculator', function(){ options.sort_method = 'QuickSort'; } );
                }

                function create_additional_menu_entries(local_items, entry_array){
                    for (let entry_index in entry_array){
                        let entry = entry_array[entry_index];
                        if (entry.items !== undefined){
                            let submenu_items = {};
                            create_additional_menu_entries(submenu_items, entry.items);
                            local_items[entry.label] = {
                                name: "<span class='"+entry.icon_class+"' style='float:left'></span><span title='"+entry.hint+ "'>&nbsp;"+entry.caption+"</span>",
                                isHtmlName: true,
                                items: submenu_items
                            }
                        } else {
                            add_item_to_context_menu(local_items, entry.caption, entry.icon_class, entry.action, entry.hint)
                        }
                    }
                }
                create_additional_menu_entries(items, additional_menu_entries);

                return {
                    items: items
                };
            }
        });
    }

    _grid2CSV(grid_id){
        function escape(cell){
            return cell.replace(/"/g,"\\\"").replace(/'/g,"\\\'").replace(/;/g, "\\;");
        }

        try {
            var grid_div = jQuery("#"+grid_id);
            var grid = grid_div.data("slickgrid");
            var data = "";

            grid_div.find(".slick-header-columns").children().each(function(index, element) {
                data += '"'+escape(jQuery(element).text())+'";'
            });
            data += "\n";

            var grid_data    = grid.getData().getItems();
            var grid_columns = grid.getColumns();

            for (var data_index in grid_data){
                for (var col_index in grid_columns){
                    data += '"'+escape(grid_data[data_index][grid_columns[col_index]['field']])+'";'
                }
                data += "\n"
            }

            var byteNumbers = new Uint8Array(data.length);
            for (var i = 0; i < data.length; i++) {
                byteNumbers[i] = data.charCodeAt(i);
            }
            var blob = new Blob([byteNumbers], {type: "text/csv"});
            var uri = URL.createObjectURL(blob);

            var link = document.createElement("a");
            link.download = 'Panorama_Export.csv';
            link.href = uri;

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

        } catch(e) {
            alert('Error in grid2CSV: '+(e.message === undefined ? 'No error message provided' : e.message)+'! Eventually using FireFox will help.');
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
            sle.calculate_current_grid_column_widths("resize_slickGrids");
            gridContainer.data('last_resize_width', sle.get_grid_parent_width()); // persistieren Aktuelle Breite
        }
    });
}

var in_slickgrid_resize_handler_timeout = false;
// Empfänger der Resize-events
function resize_handler(){
    if(in_slickgrid_resize_handler_timeout !== false)
        clearTimeout(in_slickgrid_resize_handler_timeout);
    in_slickgrid_resize_handler_timeout = setTimeout(resize_slickGrids, 100); //200 is time in milliseconds
}

jQuery(window).resize(function(){ resize_handler();});                      // Onetime registration of resize event handler at first load


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
        column.width_calculation_finished = true;                            // signal for single cell draws
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
        var column_metadata = rec['metadata']['columns'][column.field];  // Metadata der Spalte der Row

        if (!column_metadata['dc']){
            column_metadata['dc'] = true;
            var fullvalue = HTML_Formatter_prepare(slickGrid, current_row, column.position, rec[column.field], column, rec, column_metadata);

            fullvalue =  fullvalue.replace(/<wbr>/g, '');                       // entfernen von vordefinierten Umbruchstellen, da diese in der Testzelle sofort zum Umbruch führen und die Ermittlung der Darstellungsbreite fehlschlägt

            if (column.cssClass)
                fullvalue = "<span class='" +column.cssClass+ "'>"+fullvalue+"</span>";

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
 * Get inner style of element if requested
 * @param slickGrid     SlickGridExtended-Object
 * @param columnDef     Column definition object
 * @param column_metadata   Metadata of column for this row
 * @param value         Value of cell
 * @return {string}
 */
function html_formatter_background_style(slickGrid, columnDef, column_metadata, value) {
    let total_value = null;

    if (columnDef.show_pct_col_sum_background && columnDef.column_sum > 0 )
        total_value = columnDef.column_sum;

    if ('pct_total_value' in column_metadata)
        total_value = parseFloat(column_metadata.pct_total_value);

    if (total_value !== null) {
        let pct_value = Math.round(slickGrid.parseFloatLocale(value) * 100 / total_value);
        return "background-image: -webkit-linear-gradient(left, gray 0%, lightgray "+pct_value+"%, rgba(255, 255, 255, 0) "+pct_value+"%, rgba(255, 255, 255, 0) 100%); "+
            "background-image: -moz-linear-gradient(left, gray 0%, lightgray "+pct_value+"%, rgba(255, 255, 255, 0) "+pct_value+"%, rgba(255, 255, 255, 0) 100%);    "+
            "background-image: linear-gradient(left, gray 0%, lightgray "+pct_value+"%, rgba(255, 255, 255, 0) "+pct_value+"%, rgba(255, 255, 255, 0) 100%);         "
        ;
    }
    return '';
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
    if (columnDef['show_pct_col_sum_hint'] && columnDef['column_sum'] > 0 ){
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

    let inner_style = html_formatter_background_style(slickGrid, columnDef, column_metadata, value);
    if (inner_style !== "")
        output += "<div style='"+inner_style+"'>"+fullvalue+"</div>";
    else
        output += fullvalue;

    output += "</div>";
    return output;
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
            'en': 'Show content of table cell in popup window (for better copy & paste).\nAlso reachable by double click in table cell.',
            'de': 'Anzeige des Inhaltes des Tabellenfeldes in Popup-Fenster (zum Markieren und Kopieren).\nAuch erreichbar durch Doppelklick in Tabellenzelle.'
        },
        'slickgrid_context_menu_hide_filter': {
            'en': 'Hide search filter',
            'de': 'Suchfilter ausblenden'
        },
        'slickgrid_context_menu_hide_filter_hint': {
            'en': 'Hide column-specific search filter in first line of table',
            'de': 'Ausblenden des spalten-spezifischen Suchfilters in erster Zeile der Tabelle'
        },
        'slickgrid_context_menu_line_height_full': {
            'en': 'Line height for full visible content',
            'de': 'Zeilenhöhe für volle Anzeige Feldinhalt'
        },
        'slickgrid_context_menu_line_height_full_hint': {
            'en': 'Display the of complete content of cell and enlarge line height if necessary',
            'de': 'Anzeige des kompletten Feld-Inhaltes mit Erweiterung der Zeilenhöhe bei Bedarf'
        },
        'slickgrid_context_menu_line_height_single': {
            'en': 'Line height for single line only',
            'de': 'Zeilenhöhe für einzeiligen Text'
        },
        'slickgrid_context_menu_line_height_single_hint': {
            'en': 'Display of one text line only and reduce line height if necessary',
            'de': 'Anzeige nur einer Textzeile des Feld-Inhaltes und Reduktion der Zeilenhöhe bei Bedarf'
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
            'en': 'Toggle search filter for columns',
            'de': 'Ein- und Ausblenden der Suchfilter für Spalten'
        },
        'slickgrid_context_menu_show_filter': {
            'en': 'Show search filter',
            'de': 'Suchfilter einblenden'
        },
        'slickgrid_context_menu_show_filter_hint': {
            'en': 'Show column-specific search filter in first line of table',
            'de': 'Anzeigen des spalten-spezifischen Suchfilters in erster Zeile der Tabelle'
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




"use strict";

// Zeichnen eines Diagrammes auf Basis des flot-Plugins
// Peter Ramm, 25.10.2015
//
// Factory + Class-based implementation.
//
// Options structure (passed to flot-Plugin's plot()):
//   plot_diagram:    { locale: 'en', multiple_y_axes: false }
//   xaxes:           [{ mode: 'time' }]
//   yaxis:           { show: true [, min: 0] }
//   series:          { lines: { show: true }, points: { show: true } }
//   selection:       { mode: 'x', color: 'gray', shape: 'bevel', minSize: 4 }
//   legend:          { labelFormatter: (label, series) => '<a href="#'+label+'">'+label+'</a>' }
//   plotselected_handler: function(xstart, xend) — called with timestamps in ms since 1970


/**
 * Factory: create + return a plot diagram. Destroys any previous diagram in parent_id.
 */
function plot_diagram(unique_id, parent_id, caption, data_array, options){
    jQuery.contextMenu('destroy', '#' + parent_id);                             // remove the previous context menu registration
    jQuery('#'+parent_id).off();                                                //  Remove all handlers from the element
    jQuery('#'+parent_id).children().remove();                                  //  Remove the DOM element of the whole diagram below
    return new plot_diagram_class(unique_id, parent_id, caption, data_array, options);
}

/**
 * Refresh an existing diagram with new data, async because it may be called from a context menu event handler.
 */
function refresh_existing_diagram(pd){
    setTimeout(
        () => plot_diagram(pd.unique_id, pd.parent_id, pd.caption, pd.data_array, pd.getOptions()),
        1
    );
}


class plot_diagram_class {
    constructor(unique_id, parent_id, caption, data_array, options){
        // Public attributes
        this.unique_id  = unique_id;
        this.parent_id  = parent_id;
        this.caption    = caption;
        this.data_array = data_array;

        // Internal IDs and state
        this.plot_area_id = `diagram_${unique_id}`;
        this.canvas_id    = `canvas_${unique_id}`;
        this.head_id      = `head_${this.canvas_id}`;
        this.toolTipID    = `${this.canvas_id}_ToolTip`;
        this._updateLegendTimeout  = null;
        this._latestPosition       = null;
        this._legend_values        = null;                                      // last legend column with current values
        this._legend_indexes       = {};                                        // map { legend-name: index in legend }
        this._legendXAxis          = null;                                      // jQuery handle, set in registerLegend
        this._previousToolTipPoint = null;
        this._plot                 = null;                                      // jQuery.plot(...) handle, set below

        this.plot_area = jQuery(`<div id='${this.plot_area_id}'></div>`).appendTo(`#${parent_id}`);

        if (options === undefined)
            options = {};

        const default_options = {
            plot_diagram:   { locale: 'en', multiple_y_axes: false },
            series:         { stack: false, lines: { show: true, fill: false }, points: { show: true } },
            crosshair:      { mode: "x" },
            grid:           { hoverable: true, autoHighlight: false },
            yaxis:          { show: true },
            xaxes:          [{ mode: 'time' }],
            legend:         { position: "ne" },
            canvas_height:  450
        };

        // Hide point markers if any series has more than 100 values
        jQuery.each(data_array, (_i, val) => {
            if (val.data.length > 100)
                default_options.series.points.show = false;
        });

        // deep merge defaults and options, without modifying defaults
        this.options = jQuery.extend(true, {}, default_options, options);
        const opts = this.options;                                              // local alias to keep the rendering block readable

        this.plot_area
            .css("background-color", "white")
            .addClass('plot_diagram')                                           // marks all active diagrams for resize_plot_diagrams()
            .data('plot_diagram', this)                                         // access object via DOM
            .html(
                `<div id="${this.head_id}" class="slick-shadow" style="float:left; width:100%; background-color: white; padding-bottom: 5px;"></div>` +
                `<div id="${this.canvas_id}" class="slick-shadow" style="float:left; width:100%; height: ${opts.canvas_height}px; background-color: white; margin-bottom: 10px;"></div>`
            )
            .resize(() => resize_plot_diagrams());

        // Header area
        jQuery(`#${this.head_id}`)
            .html(`<div style="float:left; padding:3px;">${caption}</div><div align="right"><input class="close_diagram_${unique_id}" type="button" title="Diagramm Schliessen" value="X"></div>`)
            .css('margin-top', '5px')
            .find(`.close_diagram_${unique_id}`).click(() => this._remove_diagram());

        // Assign distinct y-axes if multiple_y_axes is on
        jQuery.each(data_array, (i, val) => {
            val.yaxis = opts.plot_diagram.multiple_y_axes === true ? data_array.length - i : 1;
        });

        const canvas = jQuery(`#${this.canvas_id}`);
        this._plot = jQuery.plot(canvas, data_array, opts);                     // draw

        if (opts.plotselected_handler){
            canvas.bind("plotselected", (event, ranges) => {
                opts.plotselected_handler(ranges.xaxis.from, ranges.xaxis.to);
            });
        }

        // Make canvas vertically resizable via the bottom slider
        canvas.resizable({});
        canvas.find(".ui-resizable-e").remove();                                // hide right resize cursor
        canvas.find(".ui-resizable-se").remove();                               // hide bottom-right resize cursor

        if (data_array.length === 0){
            return;                                                             // nothing more to do if there's no data
        }

        this._build_context_menu();
        this.registerLegend();
    } // constructor


    get_plot()   { return this._plot;   }
    getOptions() { return this.options; }


    _build_context_menu(){
        const opts          = this.options;
        const plot_area_id  = this.plot_area_id;

        function add_item_to_context_menu(items, label, icon_class, click_action, hint){
            items[label] = {
                name: `<span class='${icon_class}' style='float:left'></span><span title='${hint}'>&nbsp;${label}</span>`,
                isHtmlName: true,
                callback: click_action,
            };
        }

        // !!! Don't directly reference the plot object in event handlers because this may result in memory leaks.
        // Look up the instance via DOM each time.
        jQuery(`#${this.parent_id}`).contextMenu({
            selector: 'div',
            build: ($trigger, _e) => {
                const items = {
                    header: {
                        name: '<b>Diagram</b>',
                        isHtmlName: true,
                        disabled: true
                    }
                };

                add_item_to_context_menu(items,
                    opts.yaxis.show ? this._locale_translate('diagram_y_axis_hide_name') : this._locale_translate('diagram_y_axis_show_name'),
                    'cui-expand-left',
                    () => {
                        const pd = jQuery(`#${plot_area_id}`).data('plot_diagram');
                        const o = pd.getOptions();
                        o.yaxis.show = !o.yaxis.show;
                        refresh_existing_diagram(pd);
                    },
                    opts.yaxis.show ? this._locale_translate('diagram_y_axis_hide_hint') : this._locale_translate('diagram_y_axis_show_hint')
                );

                add_item_to_context_menu(items,
                    opts.plot_diagram.multiple_y_axes ? this._locale_translate('diagram_all_on_name') : this._locale_translate('diagram_all_off_name'),
                    'cui-sort-numeric-up',
                    () => {
                        const pd = jQuery(`#${plot_area_id}`).data('plot_diagram');
                        const o = pd.getOptions();
                        o.plot_diagram.multiple_y_axes = !o.plot_diagram.multiple_y_axes;
                        refresh_existing_diagram(pd);
                    },
                    opts.plot_diagram.multiple_y_axes ? this._locale_translate('diagram_all_on_hint') : this._locale_translate('diagram_all_off_hint')
                );

                add_item_to_context_menu(items,
                    opts.series.stack ? this._locale_translate('diagram_unstack_name') : this._locale_translate('diagram_stack_name'),
                    'cuis-chart-area',
                    () => {
                        const pd = jQuery(`#${plot_area_id}`).data('plot_diagram');
                        const o = pd.getOptions();
                        o.series.stack = !o.series.stack;
                        o.series.lines.fill = o.series.stack;
                        if (o.series.stack)
                            o.plot_diagram.multiple_y_axes = false;
                        refresh_existing_diagram(pd);
                    },
                    opts.series.stack ? this._locale_translate('diagram_unstack_hint') : this._locale_translate('diagram_stack_hint')
                );

                add_item_to_context_menu(items,
                    opts.series.points.show ? this._locale_translate('diagram_hide_points_name') : this._locale_translate('diagram_show_points_name'),
                    'cui-sort-numeric-up',
                    () => {
                        const pd = jQuery(`#${plot_area_id}`).data('plot_diagram');
                        const o = pd.getOptions();
                        o.series.points.show = !o.series.points.show;
                        refresh_existing_diagram(pd);
                    },
                    opts.series.points.show ? this._locale_translate('diagram_hide_points_hint') : this._locale_translate('diagram_show_points_hint')
                );

                return { items };
            }
        });
    }


    registerLegend(){
        this._updateLegendTimeout = null;                                       // ensure timeout is rescheduled

        // ############ Bind events
        jQuery(`#${this.canvas_id}`).bind("plothover", (event, pos, item) => {
            this._latestPosition = pos;
            if (!this._updateLegendTimeout)
                this._updateLegendTimeout = setTimeout(() => this._updateLegend(), 50);     // throttle updateLegend for crosshair + legend refresh
            if (item) {
                if (this._previousToolTipPoint !== item.dataIndex) {
                    this._previousToolTipPoint = item.dataIndex;
                    $(`#${this.toolTipID}`).remove();
                    this._showTooltip(item.pageX, item.pageY, `${item.series.label}= ${item.datapoint[1].toFixed(2)}`);
                }
            } else {
                $(`#${this.toolTipID}`).remove();
                this._previousToolTipPoint = null;
            }
        });


        // ############ Crosshair display
        const x_legend_title = this.options.xaxes[0].mode === "time" ? "Time" : 'X';

        const legend_div = jQuery(`#${this.canvas_id} .legend`);
        legend_div.children('div').detach();                                    // remove a sizing-only div before legend_table
        legend_div.find("table").addClass('legend_table');

        if (jQuery(`#${this.canvas_id} .legendXAxis`).length === 0) {           // first call only — not on resize
            // value column + close-button column
            legend_div.find("tr").each((index, elem) => {
                const tr = jQuery(elem);
                const legend_name = jQuery(tr.children('td')[1]).text();        // strip possible decoration from labelFormatter
                this._legend_indexes[legend_name] = index;
                tr.append("<td align='right' class='legend_value'></td>");

                tr.append(`<td><a href='#' title='${this._locale_translate('diagram_remove_chart')}' style='color:red' onclick='delete_single_plot_chart("${this.plot_area_id}", ${index}); return false;'>X</a></td>`);
            });

            // x-axis row
            legend_div.find("tbody").append(`<tr><td></td><td>${x_legend_title}</td><td class='legendXAxis'></td><td></td></tr>`);
        }
        this._legendXAxis   = jQuery(`#${this.canvas_id} .legendXAxis`);
        this._legend_values = jQuery(`#${this.canvas_id} .legend_value`);

        // Add titles to multiple y-axis scales
        if (this.options.plot_diagram.multiple_y_axes === true){
            jQuery.each(this.data_array, (i, val) => {
                jQuery(`#${this.canvas_id} .y${this.data_array.length - i}Axis`).attr("title", val.label);
            });
        }

        legend_div.draggable();
    }


    delete_single_chart(legend_index){
        // resolve the legend-name from index in legend table
        let legend_name = '';
        for (const [name, idx] of Object.entries(this._legend_indexes)){
            if (idx === legend_index){
                legend_name = name;
            }
        }

        // find and remove the matching curve from data_array (may be sorted differently)
        for (const [data_index, entry] of this.data_array.entries()) {
            if (entry.label === legend_name){
                if (entry['delete_callback']){
                    entry['delete_callback'](legend_name);                      // notify caller if callback provided
                }
                this.data_array.splice(data_index, 1);
                refresh_existing_diagram(this);
                return;                                                         // splice mutates — exit immediately
            }
        }
    }


    // ###################### Private helpers ######################

    _pad2(number){                                                              // zero-pad to 2 digits
        const str = `${number}`;
        return str.length < 2 ? `0${str}` : str;
    }

    _remove_diagram(){
        this.data_array.length = 0;                                             // clear contents but keep the array reference
        jQuery(`#${this.parent_id}`).children().remove();
    }

    _showTooltip(x, y, contents){
        $(`<div id="${this.toolTipID}">${contents}</div>`).css({
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

    _updateLegend(){
        this._updateLegendTimeout = null;
        const pos = this._latestPosition;

        const axes = this._plot.getAxes();
        if (pos.x < axes.xaxis.min || pos.x > axes.xaxis.max ||
            pos.y < axes.yaxis.min || pos.y > axes.yaxis.max)
            return;

        const dataset = this._plot.getData();
        for (let i = 0; i < dataset.length; ++i) {                              // iterate curves
            const series = dataset[i];

            // find the nearest points, x-wise
            let j;
            for (j = 0; j < series.data.length; ++j)
                if (series.data[j][0] > pos.x)
                    break;

            // interpolate
            const p1 = series.data[j - 1];
            const p2 = series.data[j];
            let y;
            if (p1 === undefined)
                y = p2[1];
            else if (p2 === undefined)
                y = p1[1];
            else
                y = p1[1] + (p2[1] - p1[1]) * (pos.x - p1[0]) / (p2[0] - p1[0]);

            // place value at the legend-index of this series (legend order can differ)
            jQuery(this._legend_values[this._legend_indexes[series.label]]).html(y.toFixed(2));
        }

        // Show crosshair x-position as time or number
        if (this.options.xaxes[0].mode === "time"){
            const t = new Date(pos.x);
            this._legendXAxis.html(`${this._pad2(t.getUTCDate())}.${this._pad2(t.getUTCMonth()+1)}.${t.getUTCFullYear()} ${this._pad2(t.getUTCHours())}:${this._pad2(t.getUTCMinutes())}:${this._pad2(t.getUTCSeconds())}`);
        } else {
            this._legendXAxis.html(pos.x);
        }
    }

    _locale_translate(key){
        const t = get_plot_diagram_translations();
        const locale = this.options.plot_diagram.locale;
        if (t[key]){
            if (t[key][locale])  return t[key][locale];
            if (t[key]['en'])    return t[key]['en'];
            return `No default translation (en) available for key "${key}"`;
        }
        return `No translation available for key "${key}"`;
    }
} // plot_diagram_class


function get_plot_diagram_translations(){
    return {
        'diagram_y_axis_show_name':   { 'en': 'Show y-axis',                                                      'de': 'y-Achse(n) anzeigen' },
        'diagram_y_axis_show_hint':   { 'en': 'Show all scale values of y-axis',                                  'de': 'Skalenwerte der Y-Achse(n) anzeigen' },
        'diagram_y_axis_hide_name':   { 'en': 'Hide y-axis',                                                      'de': 'y-Achse(n) ausblenden' },
        'diagram_y_axis_hide_hint':   { 'en': 'Hide scale values of y-axis',                                      'de': 'Skalenwerte der Y-Achse(n) ausblenden' },
        'diagram_all_on_name':        { 'en': 'All column curves with one scale for y-axis',                      'de': 'Alle Spalten-Kurven in einer y-Achse darstellen' },
        'diagram_all_on_hint':        { 'en': 'Show all column curves with only one scale for y-axis',            'de': 'Alle Spalten-Kurven in einer y-Achse darstellen' },
        'diagram_all_off_name':       { 'en': 'Own y-axis per curve (100% scale)',                                'de': 'Eigene y-Achse je Kurve (100% Wertebereich)' },
        'diagram_all_off_hint':       { 'en': 'Own y-axis for every column curve (each with 100% scale)',         'de': 'Eigene y-Achse je Spalten-Kurve (jede Kurve hat 100% des Wertebereich)' },
        'diagram_stack_name':         { 'en': 'Stack single charts',                                              'de': 'Stapeln der einzelnen Kurven' },
        'diagram_stack_hint':         { 'en': 'Shows values for single charts and sum simultaneously',            'de': 'Erlaubt gleichzeitige Sicht auf Einzelwerte und Summe' },
        'diagram_unstack_name':       { 'en': 'Unstack single charts',                                            'de': 'Entstapeln der einzelnen Kurven' },
        'diagram_unstack_hint':       { 'en': 'Each chart shows own values in y-axis',                            'de': 'Jede Kurve zeigt ihre eigenen Werte auf Y-Achse' },
        'diagram_hide_points_hint':   { 'en': "Don't show single values as circle on chart",                      'de': 'Einzelwerte nicht als Kreis auf der Kurve anzeigen' },
        'diagram_show_points_hint':   { 'en': 'Show single values as circle on chart',                            'de': 'Einzelwerte als Kreis auf der Kurve anzeigen' },
        'diagram_hide_points_name':   { 'en': "Don't show single values as circle",                               'de': 'Einzelwerte nicht als Kreis zeigen' },
        'diagram_show_points_name':   { 'en': 'Show single values as circle',                                     'de': 'Einzelwerte als Kreis zeigen' },
        'diagram_remove_chart':       { 'en': 'Remove this chart from diagram',                                   'de': 'Diese Kurve aus dem Diagramm entfernen' },
        'diagram_remove_chart_confirm': { 'en': 'Remove chart',                                                   'de': 'Entfernen der Kurve' },
        'diagram_save_to_image_name': { 'en': 'Save chart to image',                                              'de': 'Speichern als Bild' },
        'diagram_save_to_image_hint': { 'en': 'Save complete chart to image',                                     'de': 'Speichern des ganzen Diagrammes als Bild' }
    };
}


function resize_plot_diagrams(){
    jQuery('.plot_diagram').each((_index, element) => {
        jQuery(element).data('plot_diagram').registerLegend();
    });
}

// Remove a specific curve (called from inline onclick in the legend table)
function delete_single_plot_chart(plot_area_id, index){
    jQuery(`#${plot_area_id}`).data('plot_diagram').delete_single_chart(index);
    return false;
}

var dashboard_data = undefined;                                                 // controls if data exists to append with delta or initial read occurs



class DashboardData {
    constructor(unique_id, canvas_id, top_session_sql_id, update_area_id, dbid, rac_instance, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id, refresh_button_id, options={}){
        this.unique_id                  = unique_id;
        this.canvas_id                  = canvas_id;
        this.top_session_sql_id         = top_session_sql_id;
        this.update_area_id             = update_area_id;
        this.dbid                       = dbid;
        this.rac_instance               = rac_instance;                         // null if not used
        this.hours_to_cover             = hours_to_cover;
        this.refresh_cycle_minutes      = refresh_cycle_minutes;
        this.refresh_cycle_id           = refresh_cycle_id;
        this.refresh_button_id          = refresh_button_id;
        this.ash_data_array             = [];
        this.last_refresh_time_string   = null;
        this.current_timeout            = null;                                 // current active timeout
        this.selection_refresh_pending  = false;                                // is there a request in transit for selection? Suppress multiple events
        this.diagram                    = null;                                 // instance of plot_diagram_class
        const default_options = {
            series: {stack: true, lines: {show: true, fill: true}, points: {show: false}},
            canvas_height: 250,
            legend: {position: "nw", sorted: 'reverse'},
            selection: {
                mode: "x",
                color: 'gray',
                //shape: "round" or "miter" or "bevel",
                shape: "bevel",
                minSize: 4
            }
        };
        /* deep merge defaults and options, without modifying defaults */
        this.options = jQuery.extend(true, {}, default_options, options);
    }

    log(content){
        if (false)
            console.log(content);
    }

    // which refresh cycle is choosen in select list now
    selected_refresh_cycle(){
        return $('#'+this.refresh_cycle_id).children("option:selected").val();
    }

    set_refresh_cycle_off(){
        this.cancel_timeout();
        $('#'+this.refresh_cycle_id+' option[value="0"]').attr("selected", "selected");
        $('#'+this.refresh_button_id).attr('type', 'submit');                   // make refresh button visible
    }

    remove_aged_records(data_array){
        data_array.forEach((col) => {
            let max_date_ms = col.data[col.data.length-1][0];                   // last timestamp in array
            let min_date_ms = max_date_ms - this.hours_to_cover*3600*1000
            while (col.data.length > 0 && col.data[0][0] < min_date_ms ){
                col.data.shift();                                               // remove first record of array
            }
        });
    }

    // load data from DB
    load_refresh_ash_data(){
        // get smallest timestamp in data
        let smallest_timestamp_ms = null;
        this.ash_data_array.forEach((col) => {
            if (col.data.length > 0 && (!smallest_timestamp_ms || col.data[0][0] < smallest_timestamp_ms))
                smallest_timestamp_ms = col.data[0][0];
        });

        jQuery.ajax({
            method: "POST",
            dataType: "json",
            success: (data, status, xhr)=>{
                this.process_load_refresh_ash_data_success(data, xhr);
            },
            url: 'dba/refresh_dashboard_ash?window_width='+jQuery(window).width()+'&browser_tab_id='+browser_tab_id,
            data: {
                'instance':                 this.rac_instance,
                'hours_to_cover':           this.hours_to_cover,
                'dbid':                     this.dbid,
                'last_refresh_time_string': this.last_refresh_time_string,
                'smallest_timestamp_ms':    smallest_timestamp_ms
            }
        });
    }

    process_load_refresh_ash_data_success(response_data, xhr){
        let new_ash_data            = response_data.ash_data;
        let grouping_secs           = response_data.grouping_secs;              // Default distance in seconds between two data points
        let timestamps              = {};
        let data_to_add             = {};
        let initial_data_load       = this.ash_data_array.length == 0;          // initial or delta load
        let min_refresh_time_string = null;
        let max_refresh_time_string = null;

        let previous_timestamps = [];                                           // remember used timestamps for later tasks
        if (this.ash_data_array.length > 0){
            this.ash_data_array[0].data.forEach((tupel)=>{
                previous_timestamps.push(tupel[0]);
            });
        }

        new_ash_data.forEach((d) => {
            if (this.last_refresh_time_string == null || this.last_refresh_time_string < d.sample_time_string)
                this.last_refresh_time_string = d.sample_time_string;           // greatest known timestamp from ASH
            timestamps[d.sample_time_string] = new Date(d.sample_time_string + " GMT").getTime(); // remember all used timestamps
            if (data_to_add[d.wait_class] === undefined){
                data_to_add[d.wait_class] = {};
            }
            data_to_add[d.wait_class][d.sample_time_string] = d.sessions;

            if (!min_refresh_time_string || min_refresh_time_string > d.sample_time_string)
                min_refresh_time_string = d.sample_time_string;
            if (!max_refresh_time_string || max_refresh_time_string < d.sample_time_string)
                max_refresh_time_string = d.sample_time_string;
        });

        let min_time_ms = new Date(min_refresh_time_string + " GMT").getTime(); // start of delta time range in ms since 1970
        let max_time_ms = new Date(max_refresh_time_string + " GMT").getTime(); // end of delta time range in ms since 1970

        // add missing timestamps where no values exist for any wait class but values would be expected
        let previous_ts = null;
        if (this.ash_data_array[0] && this.ash_data_array[0].data.length > 0){       // pevious data exists, than use this to check the delay to next record
            previous_ts = this.ash_data_array[0].data[this.ash_data_array[0].data.length - 1][0];
        }
        let date_to_add = new Date(Date.UTC());
        Object.values(timestamps).forEach((timestamp_ms)=>{
            if (previous_ts && (timestamp_ms - previous_ts)/1000 > grouping_secs*2){
                // add an empty timestamp after the previous record
                let ts = previous_ts+grouping_secs*1000;
                date_to_add.setTime(ts);
                timestamps[this.date_string(date_to_add)] = ts;

                // add an empty timestamp before the current record
                ts = timestamp_ms-grouping_secs*1000;
                date_to_add.setTime(ts);
                timestamps[this.date_string(date_to_add)] = ts;
            }
            previous_ts = timestamp_ms;
        });

        // copy values and generate 0-records for gaps in time series
        for (const [key, value] of Object.entries(data_to_add)) {               // iterate over wait_classes of delta
            let wait_class_object = this.ash_data_array.find(o => o.label == key)
            if (wait_class_object === undefined){                               // create empty object in ash_data_array is not exists
                wait_class_object = { label: key, data: []}
                // generate 0 records for previous timestamps if wait class is new in delta
                previous_timestamps.forEach((ts)=>{
                    wait_class_object.data.push([ts, 0]);                       // ensure existing timestamps have a 0 record
                });
                this.ash_data_array.push(wait_class_object);
            }

            let col_data_to_add = data_to_add[key];
            // generate 0-records for gaps in time series where other wait classes have values
            Object.entries(timestamps).forEach((ts_tupel)=>{
                if (col_data_to_add[ts_tupel[0]] === undefined)
                    col_data_to_add[ts_tupel[0]] = 0;
            });

            // Sort required because 0-records are pushed to object before
            var col_data_delta_array = Object.entries(col_data_to_add).sort((a,b)=>{
                if (a[0] < b[0])
                    return -1;
                if (a[0] > b[0])
                    return 1;
                return 0;
            });

            // transform date string into ms since 1970 and remember low and high value
            col_data_delta_array.forEach((val_array)=>{
                val_array[0] = timestamps[val_array[0]];
                //val_array[0] = new Date(val_array[0] + " GMT").getTime();
            });

            wait_class_object['data'] = wait_class_object.data.concat(col_data_delta_array);    // add the delta data to the previous data
        }

        // build sum over wait_classes and sort by sums, so wait class with highest amount is on top in diagram
        this.ash_data_array.forEach((col)=>{
            var sum = 0;
            col.data.forEach((tupel)=>{
                sum += tupel[1];
            });
            col['session_sum'] = sum;
        });
        // ensure the graph with highest sum is on top in chart
        this.ash_data_array.sort((a,b)=>{
            if (a.session_sum < b.session_sum)
                return -1;
            if (a.session_sum > b.session_sum)
                return 1;
            return 0;
        });

        // remove wait_classes that do not exist in delta but exists only with 0 records in previous data
        this.ash_data_array = this.ash_data_array.filter(col=>col.session_sum > 0);

        // generate dummy records with 0 for wait_classes existing in previous data but not in new delta
        this.ash_data_array.forEach((col)=>{
            if (data_to_add[col.label] === undefined){
                let new_timestamps = Object.entries(timestamps)
                new_timestamps.sort((a,b)=>{
                    if (a[0] < b[0])
                        return -1;
                    if (a[0] > b[0])
                        return 1;
                    return 0;
                });
                new_timestamps.forEach((ts)=>{
                    col.data.push([new Date(ts[0] + " GMT").getTime(), 0]);
                });
            }
        });

        // define colors
        this.ash_data_array.forEach((col)=> {
            let color = wait_class_color(col.label);
            if (color){
                col['color'] = color;
            }
        });

        // remove and recreate the sub_canvas object to suppress "Total canvas memory use exceeds the maximum limit"
        $('#'+this.canvas_id).html('');
        let sub_canvas_id = this.canvas_id+'_sub';
        $('#'+this.canvas_id).append('<div id="'+sub_canvas_id+'"></div>');

        // react on selection in chart
        this.options.plotselected_handler = (xstart, xend)=>{
            this.set_refresh_cycle_off();
            if (!this.selection_refresh_pending)
                this.log("Refreshing selection");
            this.load_top_sessions_and_sql(xstart, xend);
            this.selection_refresh_pending = true;                              // suppress subsequent calls until ajax response is processed, set to false in Rails template _refresh_top_session_sql
        }

        // format label in legend
        this.options.legend.labelFormatter = (label, series) => {

            let label_ajax_call = "" +
                "let json_data                       = { groupfilter: {}};\n" +
                "json_data.groupfilter.DBID          = "+this.dbid+";\n" +
                "json_data.groupfilter['Wait Class'] = '"+label+"';\n" +
                "json_data.groupby                   = 'Wait Event';\n" +
                "json_data.xstart_ms                 = "+min_time_ms+";\n" +
                "json_data.xend_ms                   = "+max_time_ms+";\n" +
                "json_data.update_area               = '"+this.update_area_id+"';\n"
            ;

            // use start and ent time of selection if selected
            label_ajax_call += "let selection = jQuery('#"+sub_canvas_id+"').data('plot_diagram').get_plot().getSelection();\n";
            label_ajax_call += "if (selection){\n"
            label_ajax_call += "  json_data.xstart_ms = selection.xaxis.from;\n"
            label_ajax_call += "  json_data.xend_ms = selection.xaxis.to;\n"
            label_ajax_call += "}\n"

            if (this.rac_instance)
                label_ajax_call += "json_data.groupfilter.Instance = "+this.rac_instance+";\n"

            label_ajax_call += "ajax_html('"+this.update_area_id+"', 'active_session_history', 'list_session_statistic_historic_grouping_with_ms_times', json_data);\n"

            return '<a href="#" onclick="'+label_ajax_call+' return false;" title="Show details for this wait class grouped by wait event">' + label + '</a>';
        }

        let wait_string = ''+this.hours_to_cover+' hours';
        if (this.hours_to_cover < 1)
            wait_string = ''+Math.round(this.hours_to_cover*60)+ ' minutes';

        this.diagram = plot_diagram(this.unique_id, sub_canvas_id, 'Number of active sessions within last '+wait_string+' grouped by wait class', this.ash_data_array, this.options);

        // set selection in chart to delta just added in diagram
        if (!initial_data_load)
            this.diagram.get_plot().setSelection( { xaxis: { from: min_time_ms, to: max_time_ms}}, true);

        if (this.refresh_cycle_minutes != 0 && this.selected_refresh_cycle() != '0'){                     // not started with refresh cycle=off and refresh cycle not changed to off in the meantime
            this.log('timeout set');
            this.current_timeout = setTimeout(function(){ this.draw_refreshed_data(this.canvas_id, 'timeout')}.bind(this), 1000*60*this.refresh_cycle_minutes);  // schedule for next cycle
        }
    }

    load_top_sessions_and_sql(start_range_ms=null, end_range_ms=null){
        ajax_html(this.top_session_sql_id, 'dba', 'refresh_top_session_sql',
            {   'instance':                 this.rac_instance,
                'dbid':                     this.dbid,
                'hours_to_cover':           this.hours_to_cover,
                'last_refresh_time_string': this.last_refresh_time_string,
                'start_range_ms':           start_range_ms,
                'end_range_ms':             end_range_ms,
            });
    }

    draw_refreshed_data(current_canvas_id, caller){
        if ($('#'+current_canvas_id).length == 0)                               // is dashboard page still open and timeout for the right dashboard?
            return;                                                             // end refresh now

        if (caller == 'timeout' && this.selected_refresh_cycle() == '0')        // imediately stop timeout processing if refresh is set to off
            return;

        this.log("draw_refreshed_data "+caller);
        this.current_timeout = null;                                            // no timeout pending from now until scheduled again

        this.remove_aged_records(this.ash_data_array);
        this.load_refresh_ash_data();
        this.load_top_sessions_and_sql();

        // timeout for next refresh cycle is set after successful return from ajax call
    }

    draw_with_new_refresh_cycle(canvas_id, hours_to_cover, refresh_cycle_minutes) {
        this.hours_to_cover         = hours_to_cover;
        this.refresh_cycle_minutes  = refresh_cycle_minutes;
        this.cancel_timeout();
        this.draw_refreshed_data(canvas_id, 'new refresh cycle');
    }

    // cancel possible timeout
    cancel_timeout(){
        if (this.current_timeout) {
            this.log('clearTimeout '+this.current_timeout);
            clearTimeout(this.current_timeout);                                 // remove current aktive timeout first before
            this.current_timeout = null;
        }
    }

    // get date in YYYY/MM/DD HH24:MI:SS
    date_string(d){
        return d.getUTCFullYear() + '/' + ('0'+(d.getUTCMonth()+1)).slice(-2) + '/' + ('0'+(d.getUTCDate())).slice(-2) + ' ' +
            ('0' + d.getUTCHours()).slice(-2) + ':' + ('0' + d.getUTCMinutes()).slice(-2) + ':' + ('0' + d.getUTCSeconds()).slice(-2)
        ;
    }
}

// function to be called from Rails template
refresh_dashboard = function(unique_id, canvas_id, top_session_sql_id, update_area_id, dbid, rac_instance, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id, refresh_button_id){
    if (dashboard_data !== undefined) {
        if (dashboard_data.canvas_id != canvas_id)                              // check if dashboard_data belongs to the current element
            discard_dashboard_data();                                           // throw away old content
    }

    if (dashboard_data !== undefined) {
        dashboard_data.draw_with_new_refresh_cycle(canvas_id, hours_to_cover, refresh_cycle_minutes);
    } else {
        dashboard_data = new DashboardData(unique_id, canvas_id, top_session_sql_id, update_area_id, dbid, rac_instance, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id, refresh_button_id);
        dashboard_data.draw_refreshed_data(canvas_id, 'init');
    }
}

discard_dashboard_data = function(){
    if (dashboard_data !== undefined) {
        dashboard_data.cancel_timeout();
        dashboard_data = undefined;
    }
}

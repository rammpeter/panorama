// JS-functions for explain plan listing, used multiple in views

function explain_plan_toggle_expand(a_id, rec_id, depth, grid_id){
    var anchor = $('#'+a_id);
    //alert(grid_id);
    var grid        = $('#'+grid_id).data('slickgrid');
    var data_view   = grid.getData();
    var grid_data    = data_view.getItems();
    var row = grid_data[rec_id];

    // Ermitteln der Anzahl führender Blanks als Maß für die Hierarchietiefe
    function blank_count(value){
        var i=0;
        while ((value[i] === ' ' || value.charCodeAt(i)===160 /* &nbsp; */ || value[i] === '|') && i<value.length){
            i++;
        }
        return i;
    }

    function toggle_rows(start_rec_id, hide){
        var start_depth = blank_count(row['col0']);
        start_rec_id++;
        while (start_rec_id < grid_data.length && blank_count(grid_data[start_rec_id]['col0']) > start_depth){
            grid_data[start_rec_id]['hidden'] = hide;
            start_rec_id++;
        }

    }


    if (row['collapsed']){
        row['collapsed'] = false;
        anchor.removeClass('expand').addClass('collapse');
        toggle_rows(rec_id, false);
    } else {
        row['collapsed'] = true;
        anchor.removeClass('collapse').addClass('expand');
        toggle_rows(rec_id, true);
    }
    data_view.refresh();                                                    // Ausloesen der erneuten Verarbeitung der Filter-Funktion

}

function explain_plan_filter_collapsed_item_rows(item) {
    if (item['hidden'])
        return false;
    return true;
}



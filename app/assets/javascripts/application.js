// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

// Eigenes jQuery verwenden, da Version aus jquery_rails $.browser nicht unterstützte
// jquery_3.1.0 statt 2.1.4 führt zu Problemen beim Ändern der Spaltenbreite
//= require jquery-3.6.0.min
//= require jquery-ui.min
//= require jquery.ui.touch-punch.js
// jquery_ujs.js aus gem jquery-rails nach vendor/assets/javascript kopiert, da im gem selbst nicht gefunden, statt dessen: sprocket-Error
//= require jquery_ujs
//= require jquery-ui-timepicker-addon
//= require jquery_table2CSV
//= require flot/jquery.flot
//= require flot/jquery.flot.time
//= require flot/jquery.flot.resize
//= require flot/jquery.flot.crosshair
//= require flot/jquery.flot.selection
//= require flot/jquery.flot.stack
//= require jquery.event.drag-2.3.0
//= require slick.core
//= require slick.grid
//= require slick.dataview
//= require superfish/hoverIntent
//= require superfish/superfish
//= require jstree
//= require jquery.easytabs
//= require codemirror/codemirror.js
//= require codemirror/sql.js
//= require codemirror/search.js
//= require codemirror/searchcursor.js
//= require_tree .

"use strict";





// global gültige Variable im js, wird von EnvController.setDatabase gesetzt entsprechend der Spracheinstellung
var session_locale = "en";
var indicator_call_stack_depth = 0;                                             // only last returning ajax call is closing indicator

function log_stack(message){
    var e = new Error();
    console.log('===================' + message + '==================');
    console.log(e.stack);
}

// Handle javascript errors
window.onerror = function (msg, url, lineNo, columnNo, error) {
    hideIndicator('');                                                          // close indicator window
    indicator_call_stack_depth = 0;                                             // ensure start with 0 at next indicator open

    alert('Error: '+msg+'\nURL: '+url+'\nLine-No.: '+lineNo+'\nColumn-No.: '+columnNo+'\n'+ (error.stack ? error.stack : "" ) );
    return false;
};

// does the browser support ES6 ?
function supportsES6() {
    try {
        new Function("(a = 0) => a");
        return true;
    }
    catch (err) {
        console.log('supportsES6: ' + err);
        return false;
    }
};


// soll der Indikator angezeigt werden für aktuelle url ?
function useIndicator(url){

    function exclude_action_hit(exclude_url){
        return url.indexOf(exclude_url) !== -1;
    }

    if (url === undefined)
        return true;

    return  (!(
        exclude_action_hit('env/repeat_last_menu_action') ||
        exclude_action_hit('dba_history/getSQL_ShortText')
    ));
}

function showIndicator(url) {
    if (useIndicator(url)){                                          // Unterdrücken der Anzeige Indikator
        indicator_call_stack_depth = indicator_call_stack_depth + 1;
        jQuery("#ajax_indicator").dialog("open");
    }
}

function hideIndicator(url) {
    if (useIndicator(url)) {                                          // Unterdrücken des Löschens des Indikator
        indicator_call_stack_depth = indicator_call_stack_depth - 1;
        if (indicator_call_stack_depth < 0)
            indicator_call_stack_depth = 0;
        if (indicator_call_stack_depth === 0)                                    // last call of stacked ajax calls
            jQuery("#ajax_indicator").dialog("close");
    }
}

function closeAllTooltips(self_tooltip){
    jQuery('.tooltip_class').each(function(){                                   // Test each open tooltip to be closed
        if (!self_tooltip || jQuery(this).attr('id') !== self_tooltip.attr('id')){   // down close requestung tooltip itself
//            jQuery(this).remove();                                              // close other tooltip than requesting
            jQuery(this).fadeOut({duration: 200});                              // close other tooltip than requesting
        }
    });

}

// copy text to clipboard, must be executed from mouse action
function copy_to_clipboard(text){
    var copy_elem = jQuery('<textarea id="copy_to_clipboard_text_area">'+text+'</textarea>');

    copy_elem.css('position', 'absolute');                                      // Ensure that current scroll position is not changed

    jQuery(document.body).append(copy_elem);
    //copy_elem.focus();                                                        // not really necessary to work in Firefox. Needed by other browsers?
    copy_elem.select();

    var successful = true;
    try {
        successful = document.execCommand('copy');
    }
    catch (err) {
        successful = false;
    }
    copy_elem.remove();
    if (!successful){
        alert('Error copying following text to clipboard:\n'+text);
    }
}

// jQuery.UI Tooltip verwenden
function register_tooltip(jquery_object){
    jquery_object.tooltip({                                              // ui-tooltips verwenden
        classes: {'ui-tooltip': 'tooltip_class'},
        open: function(event, ui){
            closeAllTooltips(ui.tooltip);
        },
        show: {
            effect: "slideDown",
            duration: 200,
            delay: 1000
        },
        hide: {
            effect: "slideUp",
            duration: 200
        }
    });
}



// DOM-Tree auf doppelte ID's testen
function check_dom_for_duplicate_ids() {
    var idDictionary = {};
    jQuery('[id]').each(function() {
        idDictionary[this.id] === undefined ? idDictionary[this.id] = 1 : idDictionary[this.id] ++;
    });
    for (var id in idDictionary) {
        if (idDictionary[id] > 1) {
            var test_elem = jQuery('#'+id);
            console.warn("Duplicate html-IDs in Dom-Tree:\nID " + id + " was used " + (idDictionary[id]) + " times: "+test_elem.html());
            console.log("====================================================================================");
            test_elem.each(function(index, element) {
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
        SQL_shortText_Cache[sql_id] = "< SQL-Text: request in progress>";        // Verhindern, dass während der Abfrage erneut nachgefragt wird
        jQuery.ajax({url: "dba_history/getSQL_ShortText?sql_id="+sql_id+'&browser_tab_id='+browser_tab_id,
            dataType: "json",
            success: function(response) {
                if (response['sql_short_text']){
                    SQL_shortText_Cache[sql_id] = response['sql_short_text'];   // Cachen Ergebnis
                    set_sql_title(id, response['sql_short_text']);              // Title setzen
                    // jQuery(".ui-tooltip-content").html(get_content(id, response.sql_short_text));         // bringt hintereinander alle Treffer
                }
            }
        });
    }
}

/**
 * Write detailed exception info to browser console.
 * @param exception     Catched exception object.
 * @param xhr           Complete request object.
 */
function log_exception_to_console(exception, xhr){
    console.log(' ');
    console.log('>>>>>>>>>>> Exception catched <<<<<<<<<<<');
    console.log('Message: ' + exception.message);
    console.log('Line: ' + exception.line + ' Column: '+ exception.column);
    console.log('Source URL: '+ exception.sourceURL);
    console.log(' ');
    console.log('>>> Stack trace following:');
    exception.stack.split("\n").forEach(function(item){console.log(item);});

    console.log(' ');
    console.log('>>> xhr.responseText with line numbers following:');
    xhr.responseText.split("\n").forEach(function(item, index){console.log((index +1) + ':  ' + item);});
    console.log('>>>>>>>>>> End of exception output <<<<<<<<<<<');
}

// Process ajax success event
// Parameter:
//   data:          response data string
//   xhr:           jqXHR object
//   target:        dom-id if target for html-response
function process_ajax_success(data, xhr, target, options){
    try {
        options = options || {};

        if (!options.retain_status_message) {                                        // hide status bar not suppressed
            hide_status_bar();
        }

        if (xhr.getResponseHeader("content-type").indexOf("text/html") >= 0) {
            $('#' + target).html(data);                                               // render html in target dom-element
        } else if (xhr.getResponseHeader("content-type").indexOf("text/javascript") >= 0) {
            eval(data);                                                             // Execute as javascript
        } else {
            alert("Unsupported content type in ajax response: " + xhr.getResponseHeader("content-type"));
        }
    }
    catch(err) {
        indicator_call_stack_depth = 0;                                         // reset indicator regardless of error
        hideIndicator();
        log_exception_to_console(err, xhr);
        throw("\nException: " + err.message + "\nSee browser console for details.\n");
    }
}

// call ajax with data type html
// Parameter:
//   update_area:   div-element as target for html-response
//   controller:    Controller-name
//   action:        Action-name
//   payload:       data for transfer as JSON-object
//   options:       object with serveral options
//      element:                    DOM-Element on_click is called for (this in on_click) to bind slickgrid refresh
//      retain_status_message:      Don't hide status bar
function ajax_html(update_area, controller, action, payload, options){
    options = options || {};

    jQuery.ajax({
        method: "POST",
        dataType: "html",
        success: function (data, status, xhr) {
            process_ajax_success(data, xhr, update_area, options);              // Fill target div with html-response

            if (options.element){                                               // refresh only if valid element is given in call
                var obj = jQuery(options.element);
                if (obj.parents(".slick-cell").length > 0){                     // ajax wurde aus einer slickgrid-Zelle heraus aufgerufen
                    var grid_extended = obj.parents('.slickgrid_top').data('slickgridextended');
                    if (!grid_extended){
                        console.log("No slickgridextended found in data for "+obj.parents(".slick-cell").html());
                    } else {
                        grid_extended.save_new_cell_content(obj);               // unterstellen, dass dann auch der Inhalt dieser Zelle geändert sein könnte
                    }
                }
            }
        },
        url: controller+'/'+action+'?window_width='+jQuery(window).width()+'&browser_tab_id='+browser_tab_id,
        data: payload
    });
}


// bind ajax:success to store html-response in target
// used by ajax calls submitted via ruby methode "ajax_form"
// Ensure by "unbind" that only one handler is registered even if multiple called
// Parameter:
//   element:     DOM-Element as jQuery
//   target:      target DOM-ID for response
function bind_ajax_html_response(element, target){
    element.unbind("ajax:success").bind("ajax:success", function(event, data, status, xhr) {
        process_ajax_success(data, xhr, target);
    });
}

// einmaliges Binden der allgemeinen Ajax-Callbacks für Dokument
function bind_ajax_callbacks() {
    jQuery(document)
        .ajaxSend(function(event, jqXHR, ajaxOptions){
            closeAllTooltips();
            showIndicator(ajaxOptions.url);
        })
        .ajaxComplete(function(event, jqXHR, ajaxOptions){
            //check_dom_for_duplicate_ids();        // nur relevant fuer Debugging-Zwecke


            hideIndicator(ajaxOptions.url);
        })
        .ajaxError(function(event, jqXHR, ajaxSettings, thrownError){
            indicator_call_stack_depth = 0;                                     // Ensure indicator is hidden in any cases
            hideIndicator(ajaxSettings.url);
            jQuery("#error_dialog_status").html('Error : '+thrownError+'<br>Status: '+jqXHR.status+' ('+jqXHR.statusText+')<br/><br/>');

            var error_dialog_content = jQuery("#error_dialog_content");

            if (typeof jqXHR.responseText === 'undefined'){                        // Server nicht erreichbar
//            if (jqXHR.responseText == undefined){                               // Server nicht erreichbar
                error_dialog_content.text('Panorama-Server is not available');
            } else {
                if (jqXHR.responseText.search('Error at server ') === -1 && jqXHR.status != 500) {      // Error kommt nicht vom Server, sondern aus JavaScript des Browsers
                    log_stack('Error:' + thrownError);
                    error_dialog_content.text(jqXHR.responseText);              // Inhalt escapen vor Anzeige, damit nicht interpretiert wird
                } else {
                    error_dialog_content.html(jqXHR.responseText);              // Inhalt rendern, da vorformatierte Ausgabe vom Server
                }
            }

            //jQuery("#error_dialog_stacktrace").text((new Error()).stack);

            jQuery("#error_dialog").dialog("open")
                .css('width',  'auto')                                          // Evtl. manuelle Aenderungen des Dialoges bei vorherigen Aufrufen zuruecksetzen
                .css('height', 'auto')                                          // Evtl. manuelle Aenderungen des Dialoges bei vorherigen Aufrufen zuruecksetzen
            ;
        })
    ;
}

function rpad(org_string, max_length, compare_obj_id){
    var obj = jQuery('#length_control_dummy');
    var compare_obj = jQuery('#'+compare_obj_id);
    obj.css('font-size',    compare_obj.css('font-size'));      // Attribute anpassen mit Zielobjekt
    obj.css('font-family',  compare_obj.css('font-family'));    // Attribute anpassen mit Zielobjekt
    obj.html(org_string);
    while (obj.prop("scrollWidth") < max_length){
        org_string += '&nbsp;';
        obj.html(org_string);
    }
    return org_string;
}

// Sicherstellen, dass Menü in einer Zeile darstellbar ist, einklappen wenn zu eng
// aufgerufen über resize-Event
function check_menu_width() {
    var menu_ul =  jQuery('.sf-menu');
    var main_menu = jQuery('#main_menu');

    var menu_width = main_menu.width();
    if (menu_ul.data('unshrinked_menu_width') !== undefined)
        menu_width = menu_ul.data('unshrinked_menu_width');

    var tns_width  =  jQuery('#head_links').width();
    var total_width = jQuery('body').width();

    var matches = menu_width + tns_width < total_width-10;
    var menu_shrinked = jQuery('.sf-small-ul').length > 0;
    var menu_content;

    if (!matches && !menu_shrinked) {     // menu einklappen
        menu_ul.data('unshrinked_menu_width', menu_width);                      // merken der ursprünglichen Breites des Menus
        menu_content = menu_ul.html();
        // cuis-menu shows three horizontal stripes
        var newMenu = jQuery('<li><a class="sf-with-ul" id="menu_node_0" href="#"><span class="cuis-menu"></span></a><ul class="sf-small-ul"></ul></li>');
        menu_ul.html(newMenu);
        jQuery('.sf-small-ul').html(menu_content);
    }
    if (matches && menu_shrinked) { // menu ausklappen
        menu_content = jQuery('.sf-small-ul').html();
        menu_ul.html(menu_content);
        menu_ul.data('unshrinked_menu_width', main_menu.width());    // erneut die neue Breite merken (evtl. erstmals ausgeklappt)
    }
}

/**
 * create a read only CodeMirror object from textarea with content
 * style of object is defined in css class .CodeMirror
 * @param id    texarea DOM-id
 */
function code_mirror_from_textarea(id, cm_options, options){
    let cm = CodeMirror.fromTextArea(document.getElementById(id),
        Object.assign(cm_options, {
            mode:  "sql",
            readOnly: true
            // viewportMargin: Infinity
        })
    );

    let cm_wrapper = $(cm.getWrapperElement());
    let max_height = 450;
    if (options.max_height)
        max_height = options.max_height;

    cm_wrapper.css('margin-top', '5px');                                        // not in stylesheet to allow others to use CodeMirror without margin
    cm_wrapper.addClass('shadow');                                              // not in stylesheet to allow others to use CodeMirror without shadow
    cm_wrapper.resizable();
    cm_wrapper.parent().find(".ui-resizable-se").remove();                      // Entfernen des rechten unteren resize-Cursor
    cm_wrapper.resize(function(){cm.setSize('100%', cm_wrapper.height()); });   // Ensure that CodeMirror checks itself if vertical scrollbar is needed
    //setTimeout(function(){
        if (cm_wrapper.height() > max_height){
            cm.setSize('100%', max_height);                                     // CodeMirror must set the height, otherwhise scrollbar will not work
        }
    //},0);
}


function show_popup_message(message){
    var div_id = 'show_popup_message_alert_box';
    var msg_div = jQuery('#'+div_id);

    // create div for dialog at body if not exists
    if (!msg_div.length){
        jQuery('body').append('<div id="'+div_id+'"></div>');
        msg_div = jQuery('#'+div_id);
    }
    msg_div
        .html(message)
        .dialog({
            title:'Panorama',
            draggable:  true,
            open:       function(/*event, ui*/){ $(this).parent().focus(); },
            width:      jQuery(window).width()*0.5,
            maxHeight:  jQuery(window).height()*0.9,
            beforeClose:function(){msg_div.html('')}     // clear div before close dialog
        })
    ;

}

var status_bar_timeout;

function hide_status_bar(){
    var status_bar = jQuery('#status_bar');

    status_bar.css('display', 'none');

    //if (status_bar.css('display') != 'none'){
    //    status_bar.slideToggle(200);                                            // hide previous status message
    //    clearTimeout(status_bar_timeout);
    //}
}

function show_status_bar_message(message, delay_ms){
    delay_ms = delay_ms || 60000;

    hide_status_bar();

    jQuery('#status_bar_content').html(message);
    jQuery('#status_bar').slideToggle(1500);
    status_bar_timeout = setTimeout(function(){ hide_status_bar(); }, delay_ms);
}

function initialize_combobox_filter(select_id, filter_id){
    var opts = $('#'+select_id+' option').map(function () {
        return [[this.value, $(this).text()]];
    });
    $('#'+filter_id).keyup(function () {
        var rxp = new RegExp($('#'+filter_id).val(), 'i');
        var optlist = $('#'+select_id).empty();
        opts.each(function () {
            if (rxp.test(this[1])) {
                optlist.append($('<option/>').attr('value', this[0]).text(this[1]));
            }
        });
    });
}

/**
 * Check if a website is available / reachable
 * @param url
 * @param callback function with found state
 */
function isSiteOnline(url,callback) {
    // try to load favicon
    var timer = setTimeout(function(){
        // timeout after 5 seconds
        callback(false);
    },5000)

    var img = document.createElement("img");
    img.onload = function() {
        clearTimeout(timer);
        callback(true);
    }

    img.onerror = function() {
        clearTimeout(timer);
        callback(false);
    }

    img.src = url+"/favicon.ico";
}

/**
 * Color for wait class in graph
 * @param wait_class
 */

function wait_class_color(wait_class){
    switch(wait_class){
        case 'Administrative':
            return 'rgb(120, 131, 8)';
            break;
        case 'Application':
            return 'rgb(204, 0, 0)';
            break;
        case 'Cluster':
            return 'rgb(249, 246, 227)';
            break;
        case 'Commit':
            return 'rgb(255, 145, 77)';
            break;
        case 'Configuration':
            return 'rgb(120, 85, 8)';
            break;
        case 'Concurrency':
            return 'rgb(128, 0, 0)';
            break;
        case 'CPU':
        case 'ON CPU':
            return 'rgb(11, 244, 11)';
            break;
        case 'Other':
            return 'rgb(255, 179, 179)';
            break;
        case 'Queueing':
            return 'rgb(240, 230, 191)';
            break;
        case 'Network':
            return 'rgb(196, 181, 100)';
            break;
        case 'Scheduler':
            return 'rgb(230, 255, 236)';
            break;
        case 'System I/O':
            return 'rgb(102, 179, 255)';
            break;
        case 'User I/O':
            return 'rgb(0,0,179)';
            break;
        default:
            return null;
    }
}






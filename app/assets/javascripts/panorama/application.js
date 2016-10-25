// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

// Eigenes jQuery verwenden, da Version aus jquery_rails $.browser nicht unterstützte
// jquery_3.1.0 führt zu Problemen beim Ändern der Spaltenbreite
//= require jquery-2.1.4
//= require jquery-ui
//= require jquery.ui.touch-punch.js
// jquery_ujs.js aus gem jquery-rails nach vendor/assets/javascript kopiert, da im gem selbst nicht gefunden, statt dessen: sprocket-Error
//= require jquery_ujs
//= require jquery-ui-timepicker-addon
//= require jquery_table2CSV
//= require flot/jquery.flot
//= require flot/jquery.flot.time
//= require flot/jquery.flot.resize
//= require flot/jquery.flot.crosshair
//= require flot/jquery.flot.stack
//= require jquery.event.drag-2.2
//= require slick.core
//= require slick.grid
//= require slick.dataview
//= require superfish/hoverIntent
//= require superfish/superfish
//= require jstree
//= require_tree .

"use strict"


// global gültige Variable im js, wird von EnvController.setDatabase gesetzt entsprechend der Spracheinstellung
var session_locale = "en";

function log_stack(message){
    var e = new Error();
    console.log('===================' + message + '==================');
    console.log(e.stack);
}

// soll der Indikator angezeigt werden für aktuelle url ?
function useIndicator(url){

    function exclude_action_hit(exclude_url){
        return url.indexOf(exclude_url) != -1;
    }

    return  (!(
        exclude_action_hit('Env/repeat_last_menu_action') ||
        exclude_action_hit('DbaHistory/getSQL_ShortText')
    ));
}

function showIndicator(url) {
    if (useIndicator(url)){                                          // Unterdrücken der Anzeige Indikator
        jQuery("#ajax_indicator").dialog("open");
    }
}

function hideIndicator(url) {
    if (useIndicator(url)) {                                          // Unterdrücken des Löschens des Indikator
        jQuery("#ajax_indicator").dialog("close");
    }
}

var tooltip_document_body = null;
function closeAllTooltips(self_tooltip){
    if (tooltip_document_body == null)
        tooltip_document_body = jQuery(document.body);
    tooltip_document_body.children(".ui-tooltip").each(function(i){
        if (!self_tooltip || jQuery(this).attr('id') != self_tooltip.attr('id'))
        jQuery(this).remove();
    });

}

// jQuery.UI Tooltip verwenden
function register_tooltip(jquery_object){
    jquery_object.tooltip({                                              // ui-tooltips verwenden
        tooltipClass: 'tooltip_class',
        open: function(event, ui){
            closeAllTooltips(ui.tooltip);
        },
        show: {
            effect: "slideDown",
            duration: "fast",
            delay: 1000
        },
        hide: {
            effect: "slideUp"
        }
    });
}



// DOM-Tree auf doppelte ID's testen
function check_dom_for_duplicate_ids() {
    var idDictionary = {};
    jQuery('[id]').each(function(index, element) {
        idDictionary[this.id] == undefined ? idDictionary[this.id] = 1 : idDictionary[this.id] ++;
    });
    for (id in idDictionary) {
        if (idDictionary[id] > 1) {
            console.warn("Duplicate html-IDs in Dom-Tree:\nID " + id + " was used " + (idDictionary[id]) + " times: "+jQuery('#'+id).html());
            console.log("====================================================================================");
            jQuery('#'+id).each(function(index, element) {
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
        SQL_shortText_Cache[sql_id] = "< SQL-Text: request in progress>"        // Verhindern, dass während der Abfrage erneut nachgefragt wird
        jQuery.ajax({url: "DbaHistory/getSQL_ShortText?sql_id="+sql_id,
            dataType: "json",
            success: function(response) {
                if (response.sql_short_text){
                    SQL_shortText_Cache[sql_id] = response.sql_short_text;      // Cachen Ergebnis
                    set_sql_title(id, response.sql_short_text);                 // Title setzen
                    // jQuery(".ui-tooltip-content").html(get_content(id, response.sql_short_text));         // bringt hintereinander alle Treffer
                }
            }
        });
    }
}

// Registriere Ajax-Callbacks an konkretes jQuery-Objekt
function bind_special_ajax_callbacks(obj) {
    obj.bind('ajax:success', function(){                                        // Komischerweise funktioniert hier obj.ajaxSuccess nicht ???
         if (obj.parents(".slick-cell").length > 0){                            // ajax wurde aus einer slickgrid-Zelle heraus aufgerufen
             var grid_extended = obj.parents('.slickgrid_top').data('slickgridextended')
             if (!grid_extended){
                 console.log("No slickgridextended found in data for "+obj.parents(".slick-cell").html());
             } else {
                 grid_extended.save_new_cell_content(obj);  // unterstellen, dass dann auch der Inhalt dieser Zelle geändert sein könnte
             }
         }
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
            hideIndicator(ajaxSettings.url);
            jQuery("#error_dialog_status").html('Error : '+thrownError+'<br>Status: '+jqXHR.status+' ('+jqXHR.statusText+')<br/><br/>');

            var error_dialog_content = jQuery("#error_dialog_content");

            if (jqXHR.responseText == undefined){                               // Server nicht erreichbar
                error_dialog_content.text('Panorama-Server is not available');
            } else {
                if (jqXHR.responseText.search('Error at server ') == -1) {      // Error kommt nicht vom Server, sondern aus JavaScript des Browsers
                    log_stack('Error:' + thrownError);
                    error_dialog_content.text(jqXHR.responseText);              // Inhalt escapen vor Anzeige, damit nicht interpretiert wird
                } else {
                    error_dialog_content.html(jqXHR.responseText);              // Inhalt rendern, da vorformatierte Ausgabe vom Server
                }
            }
            // Zeileneilenumbrüche anzeigen in Dialog als <br>
            error_dialog_content.html(error_dialog_content.html().replace(/\\n/g, "<br>"));

            //jQuery("#error_dialog_stacktrace").text((new Error()).stack);

            jQuery("#error_dialog").dialog("open");
            jQuery("#error_dialog").css('width',  'auto');                      // Evtl. manuelle Aenderungen des Dialoges bei vorherigen Aufrufen zuruecksetzen
            jQuery("#error_dialog").css('height', 'auto');                      // Evtl. manuelle Aenderungen des Dialoges bei vorherigen Aufrufen zuruecksetzen
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

    var menu_width = jQuery('#main_menu').width();
    if (menu_ul.data('unshrinked_menu_width') != undefined)
        menu_width = menu_ul.data('unshrinked_menu_width');

    var tns_width  =  jQuery('#head_links').width();
    var total_width = jQuery('body').width();

    var matches = menu_width + tns_width < total_width-10;
    var menu_shrinked = jQuery('.sf-small-ul').length > 0;

    if (!matches && !menu_shrinked) {     // menu einklappen
        menu_ul.data('unshrinked_menu_width', menu_width);                      // merken der ursprünglichen Breites des Menus
        var menu_content = menu_ul.html();
        var newMenu = jQuery('<li><a class="sf-with-ul" href="#">Menu<span class="sf-sub-indicator"></span></a><ul class="sf-small-ul"></ul></li>');
        menu_ul.html(newMenu);
        jQuery('.sf-small-ul').html(menu_content);
    }
    if (matches && menu_shrinked) { // menu ausklappen
        var menu_content = jQuery('.sf-small-ul').html();
        menu_ul.html(menu_content);
        menu_ul.data('unshrinked_menu_width', jQuery('#main_menu').width());    // erneut die neue Breite merken (evtl. erstmals ausgeklappt)
    }
}

// Anzeige yellow pre mit Schatten und size-Anpassung
function render_yellow_pre(id, max_height){
    var elem = $("#"+id);

    elem.wrap('<pre class="yellow-panel"></pre>');


    if (max_height && elem.height() > max_height){
        elem.height(max_height);
        elem.css('overflow-y', 'scroll');
    }

    if (elem.prop('scrollWidth') > elem.width()){
        elem.css('overflow-x', 'scroll');
    }

    elem.resizable();
    elem.find(".ui-resizable-e").remove();                    // Entfernen des rechten resizes-Cursors
    elem.find(".ui-resizable-se").remove();                   // Entfernen des rechten unteren resize-Cursors
}










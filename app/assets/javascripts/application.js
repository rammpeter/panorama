// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

// Eigenes jQuery verwenden, da Version aus jquery_rails $.browser nicht unterstützte
//= require jquery-1.10.2
//= require jquery-ui-1.10.3.custom
//= require jquery_ujs
//= require jquery-ui-timepicker-addon
//= require jquery_table2CSV
//= require flot/jquery.flot
//= require flot/jquery.flot.resize
//= require flot/jquery.flot.crosshair
//= require jquery.event.drag-2.2
//= require slick.core
//= require slick.grid
//= require slick.dataview
//= require jquery.contextmenu.js
//= require superfish/hoverIntent
//= require superfish/superfish
//= require_tree .

// global gültige Variable im js, wird von EnvController.setDatabase gesetzt entsprechend der Spracheinstellung
var session_locale = "en";
var one_time_suppress_indicator = false;                                        // Unterdrückend er Anzeige des Indicators für einen Aufruf

function showIndicator() {
    if (!one_time_suppress_indicator)                                           // Einmaliges Unterdrücken der Anzeige Indikator
        jQuery("#ajax_indicator").dialog("open");
    else
        one_time_suppress_indicator = false;                                    // Zurücksetzen auf Default
}

function hideIndicator() {
    jQuery("#ajax_indicator").dialog("close");
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
    }).off('focusin');
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
            beforeSend: function(response) {
                one_time_suppress_indicator = true;                             // Unterdrückend der Anzeige des Indicators für einen Aufruf
            },
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
                 console.log("No slickgridextended found in data for "+inner_cell.html());
                 return;
             }
             grid_extended.save_new_cell_content(obj);  // unterstellen, dass dann auch der Inhalt dieser Zelle geändert sein könnte
         }
     });
}

// einmaliges Binden der allgemeinen Ajax-Callbacks für Dokument
function bind_ajax_callbacks() {
    jQuery(document)
        .ajaxSend(function(event, jqXHR, ajaxOptions){
            closeAllTooltips();
            showIndicator();
        })
        .ajaxComplete(function(event, jqXHR, ajaxOptions){
            check_dom_for_duplicate_ids();
            hideIndicator();
        })
        .ajaxError(function(event, jqXHR, ajaxSettings, thrownError){
            jQuery("#error_dialog_content").html('Error : '+thrownError+'<br/>Status='+jqXHR.status+' ('+jqXHR.statusText+')<br/><br/>'+jqXHR.responseText);
            jQuery("#error_dialog").dialog("open");
        })
    ;
}













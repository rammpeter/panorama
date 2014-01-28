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
 * @param {Node}              container   DOM-Container node to create the grid in.
 * @param {Array       }      data        An array of objects for databinding.
 * @param {Array}             columns     An array of column definitions.
 * @param {Object}            options     Grid options.
 **/
function SlickGridExtended(container, data, columns, options){
    columns = calculate_header_column_width(columns);                           // columns um Weiten-Info der Header erweitern

    setup_slickgrid(container, data, columns, options);             // alte Variante


    // Erzeugen der unvisible divs für Test auf Darstellungs-Dimensionen
    function create_test_divs(){

    }

    // Ermittlung Spaltenbreite der Header auf Basis der konketen Inhalte
    function calculate_header_column_width(columns){
        // DIVs für Test der resultierenden Breite von Zellen für slickGrid
        var test_header_outer      = jQuery('<div class="slick_header_column ui-widget-header" style="visibility:hidden; position: absolute; z-index: -1; padding: 0; margin: 0;"><nobr><div id="test_header" style="width: 1px; overflow: hidden;"></div></nobr></div>');
        jQuery(container).after(test_header_outer);                             // Einbinden in DOM-Baum
        var test_header         = test_header_outer.find('#test_header');       // Objekt zum Test der realen string-Breite

        // TABLE für umgebrochene Zeichenbreite
        var test_header_wrap_outer = jQuery('<table style="visibility:hidden; position:absolute; width:1;"><tr><td class="slick_header_column ui-widget-header" style="padding: 0; margin: 0;"><div id="test_header_wrap"></div></td></tr></table>');
        jQuery(container).after(test_header_wrap_outer);
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


}
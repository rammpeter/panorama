class SQL_Worksheet  {
    constructor(parent_element_id) {
        this.cm = CodeMirror(document.getElementById(parent_element_id), {
            value: "-- Place your SQL code here\n",
            mode:  "sql",
            lineNumbers: true
        });
        this.cm.setSize(null, 300);                                             // Set initial height of text area
        $(this.cm.getWrapperElement()).resizable();
        $(this.cm.getWrapperElement()).parent().find(".ui-resizable-se").remove(); // Entfernen des rechten unteren resize-Cursors

        $(this.cm.getWrapperElement()).bind("keydown", function(event) {
            if (event.ctrlKey == true && event.key == 'Enter'){
                sql_worksheet.exec_worksheet_sql();
                return false;
            }
            if (event.ctrlKey == true && event.key == 'e'){
                sql_worksheet.explain_worksheet_sql();
                return false;
            }
            if (event.altKey == true && event.key == 'Enter'){
                sql_worksheet.sql_in_sga();
                return false;                                                       // suppress default alt#Enter-Handling
            }
        });
        this.init_tab_container();
    }

    get_sql_at_cursor_position(){
        let return_sql;
        let selection = this.cm.getSelection();
        if (selection != ''){
            return_sql = selection;
        } else {
            let content             = this.cm.getValue();
            let content_lines       = content.split("\n");
            let cursor_pos_line     = this.cm.getCursor().line;
            let current_stmt_end_line;
            let prev_cursor_pos_line;                                           // remember prev. cursor_pos_line after shift for comparison in while
            do {
                prev_cursor_pos_line = cursor_pos_line;                         // remember prev. cursor_pos_line after shift for comparison in while
                current_stmt_end_line = this.find_stmt_end(content_lines);
                if (current_stmt_end_line != null && current_stmt_end_line < cursor_pos_line){ // remove trailing SQLs if not current SQL
                    for (var i=0; i<=current_stmt_end_line; i++)
                        content_lines.shift();
                    cursor_pos_line = cursor_pos_line - (current_stmt_end_line+1);  // new position cursor in rest of content_lines
                }
            } while (current_stmt_end_line != null && current_stmt_end_line < prev_cursor_pos_line);
            if (current_stmt_end_line != null){                                 // remove follwing SQLs if exist
                content_lines.length = current_stmt_end_line + 1;               // cut the rest of the array lines
            }
            return_sql = content_lines.join("\n");
        }
        return_sql = return_sql.trim();                                         // remove whitespaces
        // if (return_sql[return_sql.length-1] == ';')
        //     return_sql = return_sql.slice(0, -1);                            // remove trailing ;
        return return_sql;
    }

    // find line number of the end of a stmt (;,/)
    find_stmt_end(content_lines){
        for (let i=0; i<content_lines.length; i++){
            let trimmed_line = content_lines[i].trim();
            let last_char = trimmed_line[trimmed_line.length-1];
            if (last_char == ';' || last_char == '/'){
                return i;
            }
        }
        return null;
    }

    init_tab_container(){
        $( "#sql_worksheet_tab_container" ).easytabs({animate: false}); // initialize tabs
        $("#sql_worksheet_tab_container > .etabs").children().css('display', 'none');   // Hide all tab header at start
    }


    open_and_focus_tab(tab_id, controller, action){
        var tab_obj = $('#'+tab_id+'_area_sql_worksheet_id');
        tab_obj.parent().css('display', 'inline-block');                        // make tab header visible
        tab_obj.click();                                                        // bring tab in foreground

        var sql_statement = this.get_sql_at_cursor_position();
        setTimeout(function(){
            ajax_html(tab_id+'_area_sql_worksheet', controller, action, {update_area: tab_id+'_area_sql_worksheet', sql_statement: sql_statement});
        }, 100);                                                                  // Wait until click is processed to hit the visible div
    }

    exec_worksheet_sql(){
        this.open_and_focus_tab('result', 'addition', 'exec_worksheet_sql');            // bring tab in front
    }


    explain_worksheet_sql(){
        this.open_and_focus_tab('explain', 'addition', 'explain_worksheet_sql');            // bring tab in front
    }

    sql_in_sga(){
        this.open_and_focus_tab('sga', 'dba_sga', 'list_last_sql_from_sql_worksheet');            // bring tab in front
    }


}
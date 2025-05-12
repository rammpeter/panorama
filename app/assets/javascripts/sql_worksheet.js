class SQL_Worksheet  {
    /**
     *
     * @param parent_element_id
     * @param file_open_id
     * @param auto_trace_on boolean true if autotrace is on
     */
    constructor(parent_element_id, file_open_id, autotrace_on) {
        this.cm = CodeMirror(document.getElementById(parent_element_id), {
            value: "-- Place your SQL code here\n",
            mode:  "sql",
            lineNumbers: true
            // lineSeparator: "\n) // does not make sense here because textfield will also return "\r\n", handled at server side now
        });
        this.file_open_id = file_open_id;
        this.autotrace_on = autotrace_on;
        this.register_file_open();                                              // register file open event
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
            return_sql = selection.trim();                                      // Use selection but remove whitespaces
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
            // remove empty content_lines
            for (let i=0; i<content_lines.length; i++){
                if (content_lines[i].trim() == ''){
                    content_lines.splice(i, 1);
                    i--;
                }   // remove empty lines
            }
            return_sql = content_lines.join("\n").trim();                       // join lines to one string and remove whitespaces
            // check if SQL is a PL/SQL block beginning with DECLARE, BEGIN or CREATE without selection and with multiple lines
            if (return_sql.match(/^(DECLARE|BEGIN|CREATE)/i) && content_lines.length > 1) {
                return_sql = 'PL/SQL';                                          // mark as PL/SQL without selection
            }
        }

        return return_sql;
    }

    // find line number of the end of a stmt (;,/)
    find_stmt_end(content_lines){
        for (let i=0; i<content_lines.length; i++){
            let trimmed_line = content_lines[i].trim();
            let last_char = trimmed_line[trimmed_line.length-1];
            if (last_char == ';' || trimmed_line == '/'){
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
        if (sql_statement == 'PL/SQL') {
            show_popup_message("The code under the cursor is a multiline PL/SQL or create statement!<br/>Please select the whole code block to execute in editor and try again.");
        } else {
            setTimeout(function(){
                ajax_html(tab_id+'_area_sql_worksheet', controller, action, {update_area: tab_id+'_area_sql_worksheet', sql_statement: sql_statement});
            }, 100);                                                                  // Wait until click is processed to hit the visible div
        }
    }

    register_file_open() {
        const fileInput = document.getElementById(this.file_open_id);
        // const fileContent = document.getElementById('fileContent');

        fileInput.addEventListener('change', function () {
            const selectedFile = fileInput.files[0]; // Get the first selected file

            if (selectedFile) {
                const reader = new FileReader(); // Create a FileReader

                reader.onload = function (e) {
                    const fileText = e.target.result; // Get the file content
                    sql_worksheet.cm.setValue(fileText);
                    // fileContent.textContent = fileText; // Display the content in the <pre> element
                };
                reader.readAsText(selectedFile); // Read the selected file as text
            }
        });
    }

    file_open() {
        jQuery('#'+this.file_open_id).click();
    }

    file_save_as() {
        // Get the text content from the textarea
        const textContent = this.cm.getValue();

        // Create a Blob from the text content
        const blob = new Blob([textContent], { type: 'text/plain' });

        // Create a download link for the Blob
        const downloadLink = document.createElement('a');
        downloadLink.href = URL.createObjectURL(blob);
        downloadLink.download = 'sql_worksheet.sql'; // Set the desired filename and extension
        // Trigger a click event on the download link to simulate the download
        downloadLink.style.display = 'none';
        document.body.appendChild(downloadLink);
        downloadLink.click();
        document.body.removeChild(downloadLink);
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

    /**
     * change the autotrace mode
     */
    toggle_autotrace() {
        jQuery.ajax({
            method: 'POST',
            dataType: 'html',
            success: function () {
                sql_worksheet.autotrace_on = !sql_worksheet.autotrace_on;
                let icon = $('.autotrace-icon');
                icon.removeClass('cui-audio').removeClass('cuis-audio');
                icon.addClass(sql_worksheet.autotrace_on ? 'cuis-audio' : 'cui-audio');
            },
            url: ('env/remember_client_setting?window_width='+jQuery(window).width()+'&browser_tab_id='+browser_tab_id),
            data: { 'key': 'worksheet_auto_trace', 'value': !sql_worksheet.autotrace_on },
        });
    }
}
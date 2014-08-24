# encoding: utf-8
class ApplexecController < ApplicationController
  #include ApplicationHelper       # application_helper leider nicht automatisch inkludiert bei Nutzung als Engine in anderer App

  def show_running_jobs

    @running_jobs = sql_select_all "
                      SELECT ae.ID,
                             s.Name Status,
                             a.Name,
                             ae.ExecutionStart,
                             (SELECT asp.VALUE FROM sysp.applexecaspectsum asp
                              WHERE asp.id_applexecution = ae.ID AND asp.id_aspect = 751) TotalNrOFItems
                      FROM   sysp.ApplExecution ae
                      JOIN   sysp.ApplExecutionStatus s ON s.ID = ae.ID_ApplExecutionStatus
                      JOIN   sysp.Application a         ON a.ID = ae.ID_Application
                      WHERE  ae.ExecutionEnd IS NULL
                      AND    ae.ID_ApplExecutionStatus != 5 /* Ohne Success */
                      AND    ae.id_whtransferdate >= (SELECT MAX(ID_WHTransferDate)-5 FROM sysp.ApplExecution)
                      ORDER BY ae.ExecutionStart
                      "

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial => "applexec/show_running_jobs"}');"}
    end
  end
end

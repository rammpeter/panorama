# encoding: utf-8
class RuntimeController < ApplicationController

  def show_summary_history
    @daily_runtimes = sql_select_all("\
      SELECT    /*+ USE_HASH(ae) */ /* NOA-Tools Ramm */
                wd.ID_ProcessingDay,
                TO_CHAR(MIN(d.Day), 'DAY') WeekDay,
                MIN(Day) ProcessingDay,
                SUM(ae.ExecutionEnd-ae.ExecutionStart)*24 TotalHours,
                SUM(DECODE(wd.ID_WHTransferType, 5, ae.ExecutionEnd-ae.ExecutionStart, 0))*24 NachtLVHours,
                SUM(DECODE(wd.ID_WHTransferType, 1, ae.ExecutionEnd-ae.ExecutionStart,  3, ae.ExecutionEnd-ae.ExecutionStart, 0))*24 MittagLVHours,
                Count(*) JobCount
      FROM  sysp.Applexecution ae,
           sysp.WHTransferDate wd,
           sysp.ProcessingDay d
      WHERE wd.ID = ae.ID_WHTransferDate
      AND   d.ID  = wd.ID_ProcessingDay
      AND   ae.ID_Application NOT IN (120,128)
      AND   ae.ExecutionStart IS NOT NULL
      AND   ae.ExecutionEnd IS NOT NULL
      GROUP BY wd.ID_ProcessingDay
      ORDER BY 3 DESC")

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "runtime/show_summary_history" }');"}
    end
  end #show_summary_history
end

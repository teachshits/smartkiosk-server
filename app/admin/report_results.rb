ActiveAdmin.register ReportResult do
  actions :show

  menu false

  member_action :excel do
    report_result = ReportResult.find(params[:id])

    report   = report_result.report
    result   = report_result.data
    fields   = result.first.keys

    package = Axlsx::Package.new do |p|
      p.workbook.add_worksheet(:name => "Report") do |ws|
        bold = ws.styles.add_style :b => true, :alignment=> {:horizontal => :center}
        ws.add_row fields.map{|x| view_context.localize_report_fields(x)[0]}, :style => bold

        result.each do |r|
          row = []
          fields.each{|f| row << r[f]}
          ws.add_row row
        end
      end
    end

    package.use_shared_strings = true
    send_data package.to_stream.read, :filename => 'report.xlsx',
      :type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  end

  #
  # SHOW
  #
  action_item :only => [:show] do
    link_to I18n.t('smartkiosk.admin.actions.report_results.excel'),
      excel_admin_report_result_path(report_result)
  end

  show do
    attributes_table do
      row :rows
      row :report
      row :created_at
    end

    panel I18n.t('smartkiosk.admin.panels.report_results.data') do
      report = report_result.report
      result = report_result.data
      fields = result.first.try(:keys) || []
      table do
        tr do
          fields.each do |field|
            th localize_report_fields(field)[0]
          end
        end
        result.each do |row|
          tr do
            fields.each do |field|
              td row[field]
            end
          end
        end
      end
    end
  end
end

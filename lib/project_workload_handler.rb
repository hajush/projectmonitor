class ProjectWorkloadHandler

  attr_reader :project

  def initialize(project)
    @project = project
  end

  def workload_complete(workload)
    status_content = workload.recall(:feed_url)
    build_status_content = workload.recall(:build_status_url)

    update_ci_status(workload, status_content, build_status_content)
  end

  def workload_failed(e)
    error_text = e.try(:message)
    error_backtrace = e.try(:backtrace).try(:join,"\n")
    project.payload_log_entries.build(error_type: "#{e.class}", error_text: "#{e.try(:message)}", update_method: "Polling", status: "failed", backtrace: "#{error_text}\n#{error_backtrace}")
    project.building = project.online = false
    project.save!
  end

private

  def update_ci_status(workload, status_content, build_status_content = nil)
    payload = project.fetch_payload

    payload.status_content = status_content
    payload.build_status_content = build_status_content if project.build_status_url

    payload_processor = PayloadProcessor.new(project_status_updater: StatusUpdater.new)
    log = payload_processor.process_payload(project: project, payload: payload)
    log.update_method = 'Polling'
    log.save!

    project.online = true
    project.save!

  rescue => e
    project.reload
    project.payload_log_entries.build(error_type: "#{e.class}", error_text: "#{e.message}", update_method: "Polling", status: "failed", backtrace: "#{e.message}\n#{e.backtrace.join("\n")}")
    project.online = false
    project.save!
  end

end

module MyPullRequestsHelper
  def pull_request_column_classes(column)
    case column.to_sym
    when :reviewing
      "border-amber-400/35 bg-amber-500/10"
    when :approved
      "border-emerald-400/35 bg-emerald-500/10"
    when :changes_requested
      "border-rose-400/35 bg-rose-500/10"
    when :draft
      "border-slate-700 bg-slate-900/90"
    else
      "border-sky-400/30 bg-sky-500/10"
    end
  end
end

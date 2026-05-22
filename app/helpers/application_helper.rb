module ApplicationHelper
  def nav_item_base_class
    "inline-flex items-center rounded-full px-4 py-2 text-sm font-medium transition"
  end

  def nav_link_class(path)
    if current_page?(path)
      "#{nav_item_base_class} bg-brand-500/15 text-brand-200 ring-1 ring-inset ring-brand-400/40"
    else
      "#{nav_item_base_class} text-slate-300 hover:bg-slate-900 hover:text-white"
    end
  end

  def nav_button_class
    "#{nav_item_base_class} text-slate-300 hover:bg-slate-900 hover:text-white cursor-pointer"
  end

  def flash_class(type)
    case type.to_sym
    when :notice
      "border border-emerald-500/30 bg-emerald-500/10 text-emerald-200"
    when :alert
      "border border-rose-500/30 bg-rose-500/10 text-rose-200"
    else
      "border border-slate-700 bg-slate-950/80 text-slate-200"
    end
  end
end

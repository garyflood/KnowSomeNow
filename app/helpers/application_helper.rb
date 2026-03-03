module ApplicationHelper
  def markdown(text)
    return "" if text.blank?

    options = { filter_html: true, hard_wrap: true, link_attributes: { rel: "nofollow", target: "_blank" } }
    extensions = { autolink: true, superscript: true, fenced_code_blocks: true }
    renderer = Redcarpet::Render::HTML.new(options)
    Redcarpet::Markdown.new(renderer, extensions).render(text).html_safe
  end
end

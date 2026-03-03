module MarkdownHelper
  def markdown(text)
    options = {
      hard_wrap: true,
      filter_html: true,
      autolink: true,
      no_intra_emphasis: true
    }

    extensions = {
      fenced_code_blocks: true,
      tables: true
    }

    renderer = Redcarpet::Render::HTML.new(options)
    markdown = Redcarpet::Markdown.new(renderer, extensions)
    markdown.render(text).html_safe
  end
end

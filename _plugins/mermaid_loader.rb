Jekyll::Hooks.register :posts, :post_render do |post|
  if post.output_ext == '.html' && post.content.include?('```mermaid')
    mermaid_script = <<~HTML
      <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true, theme: "default" });
      </script>
    HTML
    post.output.gsub!('</body>', "#{mermaid_script}\n</body>")
  end
end


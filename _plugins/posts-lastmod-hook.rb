# frozen_string_literal: true

require 'open3'

# Pass filenames as literal Git pathspecs, never through a shell.
Jekyll::Hooks.register :posts, :post_init do |post|
  path = post.path.to_s
  commit_num, status = Open3.capture2(
    'git', '--literal-pathspecs', 'rev-list', '--count', 'HEAD', '--', path,
    err: File::NULL
  )
  next unless status.success? && commit_num.to_i > 1

  lastmod_date, status = Open3.capture2(
    'git', '--literal-pathspecs', 'log', '-1', '--pretty=%ad', '--date=iso', '--', path,
    err: File::NULL
  )
  post.data['last_modified_at'] = lastmod_date.strip if status.success? && !lastmod_date.strip.empty?
end

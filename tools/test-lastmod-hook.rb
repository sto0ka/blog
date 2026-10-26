# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

module Jekyll
  module Hooks
    def self.register(*_args, &block)
      @callback = block
    end

    def self.run(post)
      @callback.call(post)
    end
  end
end

load File.expand_path('../_plugins/posts-lastmod-hook.rb', __dir__)
Post = Struct.new(:path, :data)

def git(*args)
  output, status = Open3.capture2e('git', *args)
  raise "git failed: #{output}" unless status.success?
  output
end

Dir.mktmpdir('blog-lastmod-test-') do |dir|
  Dir.chdir(dir) do
    git('init', '--quiet')
    git('config', 'user.name', 'Hook test')
    git('config', 'user.email', 'hook-test@example.invalid')
    git('config', 'commit.gpgsign', 'false')

    paths = ['ordinary.md', 'space name.md', 'quote"name.md',
             'post$(touch INJECTION_MARKER).md', '-leading-dash.md', 'literal[1].md']
    paths.each { |path| File.write(path, 'first') }
    File.write('single-commit.md', 'one version')
    git('add', '--all')
    git('commit', '--quiet', '-m', 'First versions')
    paths.each { |path| File.write(path, 'second') }
    git('add', '--all')
    git('commit', '--quiet', '-m', 'Updated versions')

    paths.each do |path|
      post = Post.new(path, {})
      Jekyll::Hooks.run(post)
      expected = git('--literal-pathspecs', 'log', '-1', '--pretty=%ad', '--date=iso', '--', path).strip
      raise "Wrong date for #{path.inspect}" unless post.data['last_modified_at'] == expected
    end
    raise 'Shell command substitution executed' if File.exist?('INJECTION_MARKER')

    ['single-commit.md', 'missing.md', '*.md'].each do |path|
      post = Post.new(path, {})
      Jekyll::Hooks.run(post)
      raise "Unexpected date for #{path.inspect}" if post.data.key?('last_modified_at')
    end

    # A failed Git command must not overwrite an explicitly provided date.
    FileUtils.rm_rf('.git')
    post = Post.new('ordinary.md', { 'last_modified_at' => 'existing date' })
    Jekyll::Hooks.run(post)
    raise 'Failed Git command changed the date' unless post.data['last_modified_at'] == 'existing date'
  end
end

puts 'Last-modified hook: ordinary and hostile paths, literal pathspecs, and Git failures passed.'

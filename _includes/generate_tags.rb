require 'json'
require 'fileutils'

# Load posts.json
posts_path = '_data/posts.json'
posts = JSON.parse(File.read(posts_path))

# Extract tags with associated posts
tag_data = {}
posts.each do |post|
  post['tags'].each do |tag|
    tag_slug = tag.downcase.strip.gsub(/[^\w]+/, '-')
    tag_data[tag_slug] ||= { title: tag, count: 0, posts: [] }
    tag_data[tag_slug][:count] += 1
    tag_data[tag_slug][:posts] << { title: post['title'], link: post['link'] }
  end
end

# Ensure the "tags" directory exists
FileUtils.mkdir_p('tags')

# Generate tag files
tag_data.each do |slug, data|
  File.open("tags/#{slug}.md", 'w') do |f|
    f.write("---\n")
    f.write("layout: tag\n")
    f.write("title: #{data[:title]}\n")
    f.write("permalink: /tags/#{slug}/\n")
    f.write("count: #{data[:count]}\n")
    f.write("---\n\n")

    data[:posts].each do |post|
      f.write("- [#{post[:title]}](#{post[:link]})\n")
    end
  end
end

puts "Tag files generated for #{tag_data.keys.count} tags."

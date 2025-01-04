require 'json'

# Load posts from posts.json
posts_path = '../_data/posts.json'
posts = JSON.parse(File.read(posts_path))

# Count tags
tag_counts = Hash.new(0)
posts.each do |post|
  post['tags'].each { |tag| tag_counts[tag] += 1 }
end

# Sort tags by count in descending order and select top 10
sorted_tags = tag_counts.sort_by { |_, count| -count }.first(10)

# Create JSON structure
trending_tags = sorted_tags.map do |tag, count|
  {
    "name" => tag,
    "slug" => tag.downcase.gsub(/[^a-z0-9]+/, '-'),
    "count" => count
  }
end

# Write to _data/trending_tags.json
File.write('../_data/trending_tags.json', JSON.pretty_generate(trending_tags))
puts "Generated trending_tags.json with #{trending_tags.size} tags."

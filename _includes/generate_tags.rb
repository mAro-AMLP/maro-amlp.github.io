require 'json'
require 'fileutils'

# Configuration
SPLIT_FILES_DIR = '_data/split_posts'
OUTPUT_FILE = '_data/tags.json'

# Extract tags and count occurrences
def extract_tags(posts)
  tag_counts = {}

  posts.each do |post|
    (post['tags'] || []).each do |tag|
      clean_tag = tag.to_s.strip.downcase.gsub(/[^a-z0-9\s]/i, '').gsub(/\s+/, '-')
      tag_counts[clean_tag] = tag_counts.fetch(clean_tag, 0) + 1
    end
  end

  tag_counts
end

# Save tags to a JSON file
def save_tags_to_file(tag_counts)
  FileUtils.mkdir_p(File.dirname(OUTPUT_FILE))
  File.open(OUTPUT_FILE, 'w:utf-8') do |file|
    file.write(JSON.pretty_generate(tag_counts))
  end
  puts "Tags saved to #{OUTPUT_FILE}"
end

# Create tag files
def create_tag_files(posts)
  tag_data = {}

  posts.each do |item|
    title = item['title']
    link = item['link']
    item['tags'].each do |tag|
      original_tag = tag.strip # Trim leading and trailing spaces
      clean_tag = original_tag
                    .downcase
                    .gsub(/[^a-z0-9\s]/i, '') # Remove all special characters
                    .gsub(/\s+/, '-')         # Replace spaces with hyphens
      tag_data[clean_tag] ||= { 'count' => 0, 'links' => [], 'original_tag' => original_tag }
      tag_data[clean_tag]['count'] += 1
      tag_data[clean_tag]['links'] << { 'title' => title, 'link' => link }
    end
  end

  # Ensure the "tags" directory exists
  tag_dir = 'tags' # Directory for tag files
  FileUtils.mkdir_p(tag_dir) # Create directory if it doesn't exist

  # Generate tag files
  tag_data.each do |tag, data|
    filename = File.join(tag_dir, "#{tag}.md")
    File.open(filename, 'w:utf-8') do |f|
      f.puts "---"
      f.puts "layout: tag"
      f.puts "title: #{data['original_tag']}"
      f.puts "permalink: /tags/#{tag}/"
      f.puts "count: #{data['count']}"
      f.puts "---"
      f.puts ""
      data['links'].each do |item|
        f.puts "- [#{item['title']}](#{item['link']})"
      end
    end
  end

  tag_data # Return tag_data
end

# Load and parse all split JSON files
def load_split_files
  index_file = File.join(SPLIT_FILES_DIR, 'index.json')
  raise "Index file not found: #{index_file}" unless File.exist?(index_file)

  file_list = JSON.parse(File.read(index_file))
  posts = []

  file_list.each do |filename|
    file_path = File.join(SPLIT_FILES_DIR, filename)
    if File.exist?(file_path)
      posts.concat(JSON.parse(File.read(file_path)))
    else
      warn "File not found: #{file_path}"
    end
  end

  posts
end

# Main Script Execution
begin
  puts "Loading split files..."
  posts = load_split_files
  puts "Extracting tags..."
  tag_counts = extract_tags(posts)
  puts "Saving tags to file..."
  save_tags_to_file(tag_counts)

  puts "Creating tag files..."
  tag_data = create_tag_files(posts) # Capture the returned tag_data
  puts "Tag files generated for #{tag_data.keys.count} tags."

rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace
end

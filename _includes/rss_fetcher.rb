require 'yaml'
require 'rss'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'fileutils'
require 'openssl'
require 'net/http'
require 'uri'
require 'unidecoder'
require 'time'

def open_with_redirects(uri_str, limit = 10)
  raise ArgumentError, 'too many HTTP redirects' if limit.zero?

  uri = URI.parse(uri_str)
  response = Net::HTTP.get_response(uri)

  case response
  when Net::HTTPSuccess
    response.body
  when Net::HTTPRedirection
    location = response['location']
    warn "Redirected to #{location}"
    open_with_redirects(location, limit - 1)
  else
    response.value
  end
end

def clean_tag(tag)
  tag.to_s.strip.unicode_normalize(:nfkd).gsub(/[^a-z0-9\s]/i, '').gsub(/\s+/, '-').downcase
end

def extract_author(feed, blog_url)
  if blog_url.include?('github.io')
    blog_url.match(%r{https?://(?:www\.)?github\.io/(.+)/})[1]
  elsif feed.respond_to?(:author) && feed.author&.name
    Nokogiri::HTML(feed.author.name.to_s).text.strip
  else
    'unknown-author'
  end
end

def fetch_rss_feeds
  blog_sources = YAML.load_file('_data/blog_sources.yml')['blogs']
  aggregated_posts = []

  one_year_ago = Time.now - (2 * 365 * 24 * 60 * 60)

  blog_sources.each do |blog|
    begin
      puts "Fetching feed from: #{blog['rss']}"
      feed_content = open_with_redirects(blog['rss'])
      feed = RSS::Parser.parse(feed_content, false)

      if feed.nil?
        puts "Failed to parse feed at URL: #{blog['rss']}. Skipping."
        next
      end

      feed.items.each do |item|
        pub_date = item.pubDate || item.date || Time.now
        next if Time.parse(pub_date.to_s) < one_year_ago

        title = Nokogiri::HTML(item.title.to_s).text.strip
        link = item.link.to_s
        excerpt = Nokogiri::HTML(item.description || item.content || "No description available.").text.strip
        tags = if item.respond_to?(:categories) && item.categories
                 item.categories.map { |tag| clean_tag(tag.content || tag.term) }.reject(&:empty?)
               else
                 ["uncategorized"]
               end
        author = extract_author(feed, blog['rss'])

        aggregated_posts << {
          'title' => title,
          'link' => link,
          'pubDate' => pub_date.to_s,
          'excerpt' => excerpt,
          'tags' => tags,
          'author' => author,
          'source' => feed.channel&.title || "Unknown Feed Title"
        }
        puts "Added post: #{title}"
      end
    rescue StandardError => e
      puts "Error processing feed at URL: #{blog['rss']} - #{e.message}"
    end
  end

  aggregated_posts
end

def split_posts(posts, output_dir1, output_dir2)
  FileUtils.mkdir_p(output_dir1)
  FileUtils.mkdir_p(output_dir2)
  chunk_size = 10
  file_list1 = []  # Initialize file_list for the first directory
  file_list2 = []  # Initialize file_list for the second directory
  
  posts.each_slice(chunk_size).with_index do |slice, index|
    filename1 = File.join(output_dir1, "posts_part_#{index + 1}.json")
    File.open(filename1, 'w:utf-8') do |f|
      f.write(JSON.pretty_generate(slice))
    end
    puts "Created file: #{filename1}"
	 file_list1 << "posts_part_#{index + 1}.json"  # Add filename to file_list1

    filename2 = File.join(output_dir2, "posts_part_#{index + 1}.json")
    File.open(filename2, 'w:utf-8') do |f|
      f.write(JSON.pretty_generate(slice))
    end
    puts "Created file: #{filename2}"
	file_list2 << "posts_part_#{index + 1}.json"  # Add filename to file_list2
  end
  
# Create index file in the first directory
  index_file1 = File.join(output_dir1, 'index.json')
  File.open(index_file1, 'w:utf-8') do |f|
    f.write(JSON.pretty_generate(file_list1)) # Assuming file_list is defined somewhere
  end
  puts "Created index file: #{index_file1}"

  # Create index file in the second directory
  index_file2 = File.join(output_dir2, 'index.json')
  File.open(index_file2, 'w:utf-8') do |f|
    f.write(JSON.pretty_generate(file_list2)) # Assuming file_list is defined somewhere
  end
  puts "Created index file: #{index_file2}"
end

aggregated_posts = fetch_rss_feeds

output_dir1 = '_data/split_posts'
output_dir2 = 'assets/js/data/split_posts'
split_posts(aggregated_posts, output_dir1, output_dir2)

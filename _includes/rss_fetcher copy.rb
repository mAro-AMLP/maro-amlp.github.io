require 'yaml'
require 'rss'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'fileutils'
require 'openssl'
require 'net/http'
require 'uri'
require 'unidecoder' # Ensure this is required

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
    response.value # Raise an error for other HTTP responses
  end
end

def fetch_rss_feeds
  blog_sources = YAML.load_file('_data/blog_sources.yml')['blogs']
  aggregated_posts = []

  blog_sources.each do |blog|
    begin
      feed_content = open_with_redirects(blog['rss'])
      feed = RSS::Parser.parse(feed_content, false)

      if feed.nil?
        puts "Failed to parse feed at URL: #{blog['rss']}. Skipping."
        next
      end

      if feed.respond_to?(:items) && feed.items
        feed.items.each do |item|
          feed_title = feed.title.to_s rescue "Unknown Feed Title"

          title = if feed.feed_type == 'atom'
                      item.title.content
                  elsif item.title.respond_to?(:text)
                      Nokogiri::HTML(item.title).text
                  else
                      item.title.to_s
                  end

          link = item.link.href rescue item.link.to_s
          pub_date = (item.updated || item.pubDate).to_s rescue nil
          excerpt = (item.summary || item.description || item.content).to_s
          author = item.author || item.dc_creator || feed_title
          tags = (item.categories || []).map { |c| c.term rescue c.content rescue "Uncategorized" }

          aggregated_posts << {
            'title' => title,
            'link' => link,
            'pubDate' => Date.parse(pub_date).to_s,
            'excerpt' => Nokogiri::HTML(excerpt).text.strip[0..200],
            'author' => author,
            'tags' => tags
          }
        end
      else
        puts "No items found in feed at URL: #{blog['rss']}. Skipping."
      end
    rescue StandardError => e
      puts "Error processing feed at URL: #{blog['rss']} - #{e.message}"
    end
  end

  aggregated_posts
end

def create_tag_files(data)
  tag_data = {}

  data.each do |item|
    title = item['title']
    link = item['link']
    item['tags'].each do |tag|
      original_tag = tag.to_s
      normalized_tag = original_tag.unicode_normalize(:nfkd).gsub(/[^a-z0-9\-_]/i, '-')
      tag_data[normalized_tag] ||= { 'count' => 0, 'links' => [], 'original_tag' => original_tag }
      tag_data[normalized_tag]['count'] += 1
      tag_data[normalized_tag]['links'] << { 'title' => title, 'link' => link }
    end
  end

  tag_dir = 'tags'
  FileUtils.mkdir_p(tag_dir)

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
end

aggregated_posts = fetch_rss_feeds

# Convert titles to ASCII equivalents
aggregated_posts.each do |post|
  post['title'] = post['title'].to_ascii
end

File.open('_data/posts.json', 'w:utf-8') do |f|
  f.write(JSON.pretty_generate(aggregated_posts))
end

create_tag_files(aggregated_posts)

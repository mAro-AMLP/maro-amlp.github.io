require 'rss'
require 'open-uri'
require 'json'

def fetch_rss_feeds
  blog_sources = YAML.load_file('_data/blog_sources.yml')['blogs']
  blog_posts = []

  blog_sources.each do |source|
    begin
      open(source) do |rss|
        feed = RSS::Parser.parse(rss, false)
        feed.items.each do |item|
          blog_posts << {
            title: item.title,
            link: item.link,
            pubDate: item.pubDate,
            tags: item.categories
          }
        end
      end
    rescue => e
      puts "Error fetching #{source}: #{e.message}"
    end
  end

  File.open('_data/posts.json', 'w') { |f| f.write(JSON.pretty_generate(blog_posts)) }
end

fetch_rss_feeds

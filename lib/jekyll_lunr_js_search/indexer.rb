require 'json'

module Jekyll
  module LunrJsSearch
    class Indexer < Jekyll::Generator
      def initialize(config = {})
        super(config)

        lunr_config = {
          'excludes' => [],
          'strip_index_html' => false,
          'min_length' => 3,
          'stopwords' => 'stopwords.txt'
        }.merge!(config['lunr_search'] || {})

        @excludes = lunr_config['excludes']

        # if web host supports index.html as default doc, then optionally exclude it from the url
        @strip_index_html = lunr_config['strip_index_html']

        # stop word exclusion configuration
        @min_length = lunr_config['min_length']
        @stopwords_file = lunr_config['stopwords']

        @dev_mode = lunr_config['dev_mode']

        # File I/O: create search.json file and write out pretty-printed JSON
        @filename = 'search.json'
      end

      # Index all pages except pages matching any value in config['lunr_excludes'] or with date['exclude_from_search']
      # The main content from each page is extracted and saved to disk as json
      def generate(site)
        if @dev_mode
          if File.exist? search_json_location
            puts 'Not running indexer in dev mode since search.json exists...'
            return
          end
        end

        puts 'Running the search indexer...'

        # gather pages and posts
        items = pages_to_index(site)
        content_renderer = PageRenderer.new(site)
        index = []

        site.collections.each do |name, collection|
          collection.docs.each do |document|
            items << document
          end
        end

        items.each do |item|
          entry = SearchEntry.create(item, content_renderer)

          entry.strip_index_suffix_from_url! if @strip_index_html
          entry.strip_stopwords!(stopwords, @min_length) if File.exists?(@stopwords_file)

          index << {
            :title => entry.title,
            :url => entry.url,
            :date => entry.date,
            :categories => entry.categories,
            :collection => entry.collection,
            :class => entry.class,
            :body => entry.body,
            :excerpt => entry.body[0..140] + "…"
          }

          # puts 'Indexed ' << "#{entry.title} (#{entry.collection} - #{entry.url})"
        end

        json = {:entries => index}

        # Create destination directory if it doesn't exist yet. Otherwise, we cannot write our file there.
        Dir::mkdir(site.dest) unless File.directory?(site.dest)


        File.open(search_json_location, "w") do |file|
          file.write(JSON.pretty_generate(json))
        end

        # Keep the search.json file from being cleaned by Jekyll
        site.static_files << SearchIndexFile.new(site, site.dest, "/", @filename)
      end

    private

      def search_json_location
        File.join("search", @filename)
      end

      # load the stopwords file
      def stopwords
        @stopwords ||= IO.readlines(@stopwords_file).map { |l| l.strip }
      end

      def pages_to_index(site)
        items = []

        # deep copy pages
        site.pages.each {|page| items << page.dup }
        site.posts.each {|post| items << post.dup }

        # only process files that will be converted to .html and only non excluded files
        items.select! {|i| i.output_ext == '.html' && ! @excludes.any? {|s| (i.url =~ Regexp.new(s)) != nil } }
        items.reject! {|i| i.data['exclude_from_search'] }

        items
      end
    end
  end
end

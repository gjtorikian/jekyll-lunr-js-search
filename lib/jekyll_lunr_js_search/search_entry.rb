require 'nokogiri'

module Jekyll
  module LunrJsSearch
    class SearchEntry
      def self.create(page_or_post, renderer)
        return create_from_post(page_or_post, renderer) if page_or_post.is_a?(Jekyll::Post)
        return create_from_page(page_or_post, renderer) if page_or_post.is_a?(Jekyll::Page)
        return create_from_document(page_or_post, renderer) if page_or_post.is_a?(Jekyll::Document)
        raise 'Item type not supported'
      end

      def self.create_from_document(document, renderer)
        return if document.data["exclude_from_search"] || document.data["redirect_to"]
        body = renderer.render(document)
        data = document.to_liquid
        SearchEntry.new(data['title'], data['url'], Time.now, data['category'], body)
      end

      def self.create_from_page(page, renderer)
        title, url = extract_title_and_url(page)
        body = renderer.render(page)
        date = nil
        categories = []

        SearchEntry.new(title, url, date, categories, body, nil)
      end

      def self.create_from_post(post, renderer)
        title, url = extract_title_and_url(post)
        body = renderer.render(post)
        date = post.date
        categories = post.categories

        SearchEntry.new(title, url, date, categories, body, nil)
      end

      def self.extract_title_and_url(item)
        data = item.to_liquid
        [ data['title'], data['url'] ]
      end

      attr_reader :title, :url, :date, :categories, :body, :collection

      def initialize(title, url, date, categories, body)
        @title, @url, @date, @categories, @body, @collection = title, url, date, categories, body, collection
      end

      def strip_index_suffix_from_url!
        @url.gsub!(/index\.html$/, '')
      end

      # remove anything that is in the stop words list from the text to be indexed
      def strip_stopwords!(stopwords, min_length)
        @body = @body.split.delete_if() do |x|
          t = x.downcase.gsub(/[^a-z]/, '')
          t.length < min_length || stopwords.include?(t)
        end.join(' ')
      end
    end
  end
end

require 'nokogiri'

module Jekyll
  module LunrJsSearch
    class PageRenderer
      def initialize(site)
        @site = site
      end

      # render the item, parse the output and get all text inside of it
      def render(item)
        if item.is_a?(Jekyll::Document)
          item.output = Jekyll::Renderer.new(@site, item).run
        else
          item.render({}, @site.site_payload)
        end
        doc = Nokogiri::HTML(item.output)

        paragraphs = doc.search('//div[contains(concat(" ", normalize-space(@class), " "), " article-body ")]').map {|t| t.content }
        paragraphs = paragraphs.join(" ").gsub("\r", " ").gsub("\n", " ").gsub("\t", " ").gsub(/\s+/, " ")
        paragraphs.strip
      end
    end
  end
end


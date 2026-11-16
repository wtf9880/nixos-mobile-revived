require "pathname"
require "set"

module Processor
  # Fails the build when a page is not reachable from the site navigation or
  # from another page. The sitemap is deliberately not used as a starting
  # point: it lists every page, so it would make the check meaningless.
  class Reachability
    # Pages linked directly from the site header. These are the entry points
    # users can always reach, regardless of the content of other pages.
    Roots = %w[
      index.html
      getting-started.html
      documentation.html
      devices/index.html
      contributing.html
    ].freeze

    def initialize(sitemap, output_dir)
      @pages = sitemap.map(&:path).uniq
      @output_dir = output_dir
    end

    def generate()
      puts "[R] Checking documentation reachability..."

      known = @pages.to_set
      visited = Set.new
      queue = Roots.select { |page| known.include?(page) }

      while !queue.empty?
        page = queue.shift
        next if visited.include?(page)
        visited << page

        links_in(content_of(page), page).each do |target|
          next unless known.include?(target)
          queue << target unless visited.include?(target)
        end
      end

      unreachable = @pages.reject { |page| visited.include?(page) }.sort
      return if unreachable.empty?

      $stderr.puts "The following documentation pages are not reachable from"
      $stderr.puts "the site navigation or from another page:"
      unreachable.each { |page| $stderr.puts " - #{page}" }
      $stderr.puts ""
      $stderr.puts "Add them to a documentation index, or link them from an"
      $stderr.puts "existing page."
      exit 1
    end

    private

    def content_of(page)
      path = File.join(@output_dir, page)
      html = File.read(path)

      # Only inspect the page content. The footer links to the sitemap, and the
      # header contains the navigation itself; counting either would hide
      # orphaned pages.
      html = html.split(/<footer/, 2).first
      if html.include?('<div id="content"')
        html = html.split(/<div id="content"/, 2).last
      end
      html
    end

    def links_in(html, page)
      html.scan(/href=['"]([^'"]+)['"]/).flatten.filter_map do |href|
        next if href.start_with?("http://", "https://", "mailto:", "#", "//")

        href = href.split("#", 2).first.split("?", 2).first
        next if href.nil? || href.empty?

        target =
          if href.start_with?("/")
            href.delete_prefix("/")
          else
            File.join(File.dirname(page), href)
          end

        Pathname.new(target).cleanpath.to_s
      end
    end
  end
end

module Documents
  class Import::Nidaba < Import::Base
    def image_paths_glob
      "*rgb*any_to_png*nlbin*.png"
    end

    def metadata
      memoized do
        path = Dir.glob(File.join(working_path, "metadata*.yaml*")).first

        YAML.load(File.read(path))
      end
    end

    def elements_for(image)
      # we need to output the same kinds of elements that
      # we're outputting in the HocrParser.
      # This means that we have the following list of element
      # classes: surface, zone, grapheme, all of which are
      # instance of Parser::Element

      file_image = MiniMagick::Image.open(image.processed_image.file.file)
      image_width = file_image.width
      image_height = file_image.height

      Enumerator::Lazy.new([0]) do |result, _|
        result << Parser::Element.new(
          name: "surface",
          area: Area.new(
            ulx: 0,
            uly: 0,
            lrx: image_width,
            lry: image_height
          )
        )

        parsed_csv_entries(image).each do |entry|
          # each line here is a new line / zone

          result << Parser::Element.new(
            name: "zone",
            area: entry.area
          )

          text_words = entry.text.gsub(/\s+/, ' ').split(/ /)

          text_words.map(&:each_char).each_with_index do |characters, word_ix|
            characters.each_with_index do |character, character_ix|
              area = grapheme_area(image, entry, word_ix, text_words.count, character_ix, characters.count)

              if area.present?
                result << Parser::Element.new(
                  name: "grapheme",
                  area: area,
                  certainty: 0,
                  value: character,
                  grouping: ''
                )
              end
            end
          end
        end
      end
    end

    def grapheme_area(image, parsed_entry, word_ix, word_count, character_ix, character_count)
      area = word_area(image, parsed_entry, word_ix, word_count)

      area.try(:slice, character_ix, character_count)
    end

    def word_area(image, parsed_entry, word_ix, word_count)
      areas = word_areas_for(image, parsed_entry)

      if areas.count == word_count
        areas[ word_ix ]
      else
        # we need to split the area arbitrarily and let the users
        # draw better boxes:

        text = parsed_entry.text.gsub(/\s+/, ' ')

        normed_width = (parsed_entry.area.width / text.codepoints.count).round
        seen_spaces = 0
        start_ix = 0
        end_ix = 0

        text.chars.each_with_index do |char, ix|
          if seen_spaces == word_ix
            if !char[/\s/].nil?
              break
            end
          elsif seen_spaces == word_ix - 1
            if !char[/\s/].nil?
              start_ix = ix + 1
            end
          end

          if !char[/\s/].nil?
            seen_spaces += 1
          end
          end_ix = ix
        end

        base = parsed_entry.area

        Area.new(
          ulx: (base.ulx + normed_width * start_ix),
          lrx: (base.ulx + normed_width * end_ix),
          uly: base.uly,
          lry: base.lry
        )
      end
    end

    def word_areas_for(image, parsed_entry)
      all_word_areas(image).select do |area|
        parsed_entry.area.include? area
      end
    end

    def all_word_areas(image)
      # todo: allow memoized be indexed by arbitrary hashable
      @_all_word_areas ||= {}
      @_all_word_areas[ image.id ] ||= -> {
        doc = Nokogiri::XML(IO.read(segmentation_xml_path(image)))

        doc.css('zone[type=segment]').map do |segment|
          ulx, lrx, uly, lry = ['ulx', 'lrx', 'uly', 'lry'].map do |at|
            segment.attr(at).to_i
          end

          Area.new ulx: ulx, lrx: lrx, uly: uly, lry: lry
        end
      }.call
    end

    def segmentation_xml_path(image)
      File.join working_path, image.name.gsub(/\.png/, "_segment_tesseract.xml")
    end

    def parsed_csv_entries(image)
      all_parsed_csv_entries.select do |entry|
        image.processed_image.file.file[entry.image_path.basename.to_s].present?
      end
    end

    def all_parsed_csv_entries
      memoized do
        options = {
          headers: :first_row,
          return_headers: false
        }

        area_ix = 11
        image_path_ix = 12
        text_ix = 13
        entries = []

        CSV.foreach File.join(working_path, "data.csv"), options do |line|
          ulx, uly, lrx, lry = line[ area_ix ].gsub(/\[|\]/, '').split(',').map(&:to_i)

          area = Area.new ulx: ulx, lrx: lrx, uly: uly, lry: lry
          image_path = Pathname.new(line[ image_path_ix ])
          text = (line[ text_ix ] || "").strip

          entries << ParsedCsvEntry.new(area, text, image_path)
        end

        entries
      end
    end

    class ParsedCsvEntry
      attr_accessor :area, :text, :image_path

      def initialize(area, text, image_path)
        @area = area
        @text = text
        @image_path = image_path
      end
    end
  end
end

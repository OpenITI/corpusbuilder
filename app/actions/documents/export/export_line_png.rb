module Documents::Export
  class ExportLinePng < Action::Base
    attr_accessor :zone, :document,
      :dir_path, :image, :save, :use_zone_box

    def execute
      if should_save?
        cropped_image.save out_path
      else
        cropped_image
      end
    end

    def should_save?
      save != false
    end

    def out_path
      File.join dir_path, "#{zone.id}.png"
    end

    def cropped_image
      memoized do
        image.crop \
          line_box.x,
          line_box.y,
          [image.width - line_box.ulx, line_box.width].min,
          [image.height - line_box.uly, line_box.height].min
      end
    end

    def line_box
      memoized do
        if use_zone_box
          zone.area
        else
          Area.span_boxes graphemes.map(&:area)
        end
      end
    end

    def graphemes
      memoized do
        Graphemes::QueryLine.run!(
          zone: zone,
          document: document,
          revision: document.master.revision
        ).result
      end
    end
  end
end

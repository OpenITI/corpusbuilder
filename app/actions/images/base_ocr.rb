module Images
  class BaseOCR < Action::Base
    attr_accessor :image, :ocr_models, :format

    validates :image, presence: true
    validates :ocr_models, presence: true

    def execute
      raise StandardError, "BaseOCR should be extended by inheritamnce - not used directly"
    end

    def format
      @format || 'hocr'
    end

    def languages
      memoized do
        image.document.languages
      end
    end

    def file_path
      @_file_path ||= TempfileUtils.next_path('hocr_output')
    end

    def image_file_path
      image.processed_image.path
    end
  end
end



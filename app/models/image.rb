class Image < ApplicationRecord
  mount_uploader :image_scan, ImageScanUploader
  mount_uploader :processed_image, ProcessedImageUploader
  mount_uploader :hocr, HocrUploader

  belongs_to :document, required: false

  #validates :image_scan, presence: true

  def has_document?
    document_id.present?
  end

  def preprocessed?
    processed_image.present?
  end

  def ocred?
    hocr.present?
  end

  def processed_image_url
    "#{base_url}#{processed_image.url(:web)}"
  end

  class Short < Grape::Entity
    expose :id
    expose :name
  end
end

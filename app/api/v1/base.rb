class V1::Base < Grape::API
  mount V1::EditorsAPI
  mount V1::ImagesAPI
  mount V1::DocumentsAPI
  mount V1::AnnotationsAPI
  mount V1::AsyncResponsesAPI
  mount V1::ModelsAPI

  if ENV.fetch('TESTS_API', false)
    mount V1::TestsAPI
  end
end

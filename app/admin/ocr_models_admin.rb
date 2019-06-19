Trestle.resource(:ocr_models) do
  menu do
    item :ocr_models, icon: "fa fa-calculator", label: 'Models'
  end

  build_instance do |attrs, params|
    file = attrs.delete(:model_file)

    instance = model.new(attrs)

    instance.file = file

    instance
  end

  update_instance do |instance, attrs, params|
    file = attrs.delete(:model_file)

    instance.assign_attributes(attrs)

    instance.file = file

    instance
  end

  save_instance do |instance, attrs, params|
    action = OcrModels::Persist.run(
      model: instance
    )

    if !action.result
      for error in action.errors.full_messages
        instance.errors.add(:base, error)
      end
    end

    action.result
  end

  table do
    column :id do |model|
      link_to excerpt(model.id, '', radius: 4),
        trestle.edit_ocr_models_admin_path(id: model.id)
    end
    column :backend
    column :name
    column :languages
    actions
  end

  form do |ocr_model|
    select :backend, OcrModel.backends.keys.map { |k| [ k.to_s.titleize, k ] }
    text_field :filename
    text_field :name
    text_area :description
    select :languages, LanguageList::COMMON_LANGUAGES.map { |l| [l.name, l.iso_639_3] }, {}, { multiple: true }
    select :scripts, ScriptList::ALL.map { |s| [s.name, s.code] }, {}, { multiple: true }
    text_field :version_code
    file_field :model_file
  end
end

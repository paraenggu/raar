module V1
  class ArchiveFormatSerializer < ApplicationSerializer

    json_api_swagger_schema do
      property :attributes do
        property :codec,
                 type: :string,
                 description: 'See audio_encodings for possible values.'
        property :initial_bitrate,
                 type: :integer,
                 description: 'See audio_encodings of selected codec for possible values.'
        property :initial_channels,
                 type: :integer,
                 description: 'See audio_encodings of selected codec for possible values.'
        property :max_public_bitrate,
                 type: :integer,
                 description: 'See audio_encodings of selected codec for possible values.'
        property :created_at, type: :string, format: 'date-time', readOnly: true
        property :updated_at, type: :string, format: 'date-time', readOnly: true
      end
    end

    attributes :id, :codec, :initial_bitrate, :initial_channels, :max_public_bitrate,
               :created_at, :updated_at

  end
end

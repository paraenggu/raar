class ApidocsController < ApplicationController

  # A list of all classes that have swagger_* declarations.
  SWAGGERED_CLASSES = [
    # paths
    self,
    AudioFilesController,
    BroadcastsController,
    LoginController,
    ShowsController,
    Admin::ArchiveFormatsController,
    Admin::AudioEncodingsController,
    Admin::DowngradeActionsController,
    Admin::PlaybackFormatsController,
    Admin::ProfilesController,
    Admin::ShowsController,
    Admin::UsersController,
    # entities
    AudioFileSerializer,
    BroadcastSerializer,
    ShowSerializer,
    UnprocessableEntitySerializer,
    UserSerializer,
    Admin::ArchiveFormatSerializer,
    Admin::AudioEncodingSerializer,
    Admin::DowngradeActionSerializer,
    Admin::PlaybackFormatSerializer,
    Admin::ProfileSerializer,
    Admin::ShowSerializer,
    Admin::UserSerializer
  ].freeze

  swagger_root do
    key :swagger, '2.0'
    info do
      key :version, '1.0'
      key :title, 'RAAR Radio Archive API'
      key :description,
          'RAAR Radio Archive API. ' \
          'Some endpoints are public, other are restricted to admins.'
      license name: 'AGPL'
    end
    key :consumes, ['application/vnd.api+json']
    key :produces, ['application/vnd.api+json']

    security_definition :http_token do
      key :type, :basic
      key :description,
          'API token is passed as HTTP token authentication header: ' \
          '`Authorization: Token token="abc"`'
    end
    security_definition :api_token do
      key :type, :apiKey
      key :name, :api_token
      key :in, :query
      key :description, 'API token is passed as a query parameter'
    end

    response :unprocessable_entity do
      key :description, 'unprocessable entity'
      schema do
        property :errors, type: :array do
          items '$ref' => 'UnprocessableEntity'
        end
      end
    end

    parameter :page_number do
      key :name, 'page[number]'
      key :in, :query
      key :description, 'The page number of the list.'
      key :required, false
      key :type, :integer
    end

    parameter :page_size do
      key :name, 'page[size]'
      key :in, :query
      key :description,
          'Maximum number of entries that are returned per page. Defaults to 50, maximum is 500.'
      key :required, false
      key :type, :integer
    end

    parameter :sort do
      key :name, 'sort'
      key :in, :query
      key :description,
          'Name of the sort field, optionally prefixed with a `-` for descending order.'
      key :required, false
      key :type, :string
    end

    parameter :q do
      key :name, :q
      key :in, :query
      key :description, 'Query string to search for.'
      key :required, false
      key :type, :string
    end
  end

  def index
    render json: root_json
  end

  private

  def root_json
    Swagger::Blocks.build_root_json(SWAGGERED_CLASSES).merge(host_info)
  end

  def host_info
    secrets = Rails.application.secrets
    {}.tap do |hash|
      hash['host'] = secrets.host_name if secrets.host_name.present?
      hash['basePath'] = secrets.base_path if secrets.base_path.present?
    end
  end

end
before 'deploy:starting', 'package:artifact' do
  run_locally do
    execute 'bundle exec rails package'
    set :current_revision, File.read('dist/REVISION')
  end
end

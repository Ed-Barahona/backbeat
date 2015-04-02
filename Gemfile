source ENV.fetch('GEM_SOURCE', 'https://rubygems.org/')

gem 'rake'
ruby '1.9.3'

# Server/API
gem 'grape'
gem 'httparty'

# Database
gem 'mongoid', :git => 'https://github.com/mongoid/mongoid.git', :branch => '3.1.0-stable'
gem 'mongoid-locker', :git => 'https://github.com/mooremo/mongoid-locker.git'
gem 'delayed_job_mongoid', git: 'https://github.com/nchainani/delayed_job_mongoid.git', branch: 'replace_find_and_modify'
gem 'mongoid-indifferent-access'
gem 'uuidtools'

#active record
gem 'activerecord', require: 'active_record'
platform :jruby do
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'jdbc-postgres'
end
platform :mri do
  gem 'activerecord-postgresql-adapter'
end
gem 'foreigner'
gem 'enumerize'

# Utility
gem 'awesome_print'
gem 'mail'
gem 'sidekiq'
gem 'sidekiq-failures'
gem 'kiqstand'
gem 'application_transaction', :git => 'git@github.groupondev.com:finance-engineering/application_transaction.git'

gem 'service-discovery', :git => 'git@github.groupondev.com:groupon-api/service-discovery.git'

platforms :ruby do
  gem 'unicorn'
end

platforms :jruby do
  gem 'jruby-openssl', :require => false
  #Torquebox
  gem 'torquebox', '3.0.0'
  gem 'torquebox-messaging', '3.0.0'
  gem 'warbler'
  gem 'torquebox-server'
end

group :development do
  # Documentation
  gem 'rdoc', '~> 3.4'

  platforms :jruby do
    gem 'torquebox-capistrano-support'
  end
end

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'database_cleaner'
  gem 'rack-test'
  gem 'rspec'
  gem 'rspec-sidekiq'
  gem 'factory_girl'
  gem 'timecop'
  gem 'webmock'
  gem 'simplecov'
  gem 'external_service', :git => 'git@github.groupondev.com:finance-engineering/external_service.git'
  gem 'zip'
end

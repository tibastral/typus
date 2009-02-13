module Typus

  class << self

    ##
    # Returns a list of all the applications.
    #
    def applications
      Typus::Configuration.config.collect { |i| i.last['application'] }.compact.uniq.sort
    end

    ##
    # Returns a list of the modules of an application.
    #
    def application(name)
      Typus::Configuration.config.collect { |i| i.first if i.last['application'] == name }.compact.uniq.sort
    end

    ##
    # Returns a list of the submodules of a module.
    #
    def module(name)
      Typus::Configuration.config.collect { |i| i.first if i.last['module'] == name }.compact.uniq.sort
    end

    ##
    # Parent
    #
    #  Typus::Configuration.config['Post']['module']
    #  Typus::Configuration.config['Post']['application']
    #
    def parent(model, name)
      Typus::Configuration.config[model][name] || ''
    end

    ##
    # Return a list of models.
    #
    def models
      Typus::Configuration.config.map { |i| i.first }.sort
    end

    def resources

      all_resources = []
      Typus::Configuration.roles.each do |key, value|
        all_resources += Typus::Configuration.roles[key].keys
      end
      all_resources.uniq!

      resources = []
      all_resources.each do |resource|
        begin
          resource.constantize
        rescue
          resources << resource
        end
      end

      return resources.uniq.sort

    end

    def module_description(modulo)
      Typus::Configuration.config[modulo]['description']
    end

    def user_class
      Typus::Configuration.options[:user_class_name].constantize
    end

    def user_fk
      Typus::Configuration.options[:user_fk]
    end

    ##
    # Load configuration files, translations, modules and extensions.
    #
    def enable

      require 'typus/string'
      require 'typus/hash'

      Typus::Configuration.config!
      Typus::Configuration.roles!
      I18n.load_path += Dir[File.join("#{Rails.root}/vendor/plugins/typus/config/locales", '*.{rb,yml}')]

      require File.dirname(__FILE__) + "/../test/models" if Rails.env.test?
      require 'typus/translation_helper' if Typus::Configuration.options[:ignore_missing_translations]

      require 'typus/user'
      require 'typus/active_record'
      require 'typus/routes'
      require 'typus/export'
      require 'typus/authentication'
      require 'typus/object'
      require 'typus/greetings'

      require 'vendor/paginator'
      require 'vendor/active_record'

    end

    def generator

      # Create app/controllers/admin if doesn't exist.
      admin_controllers_folder = "#{Rails.root}/app/controllers/admin"
      Dir.mkdir(admin_controllers_folder) unless File.directory?(admin_controllers_folder)

      # Get a list of all the available app/controllers/admin
      admin_controllers = Dir['vendor/plugins/*/app/controllers/admin/*.rb']
      admin_controllers += Dir['app/controllers/admin/*.rb']
      admin_controllers = admin_controllers.map { |i| File.basename(i) }

      # Create app/views/admin if doesn't exist.
      admin_views_folder = "#{Rails.root}/app/views/admin"
      Dir.mkdir(admin_views_folder) unless File.directory?(admin_views_folder)

      # Create app/helpers/admin if doesn't exist.
      admin_helpers_folder = "#{Rails.root}/app/helpers/admin"
      Dir.mkdir(admin_helpers_folder) unless File.directory?(admin_helpers_folder)

      # Get a list of all the available app/helpers/admin
      admin_helpers = Dir['vendor/plugins/*/app/helpers/admin/*.rb']
      admin_helpers += Dir['app/helpers/admin/*.rb']
      admin_helpers = admin_helpers.map { |i| File.basename(i) }

      # Create test/functional/admin if doesn't exist.
      admin_controller_tests_folder = "#{Rails.root}/test/functional/admin"
      Dir.mkdir(admin_controller_tests_folder) unless File.directory?(admin_controller_tests_folder)

      # Get a list of all the available app/helpers/admin
      admin_controller_tests = Dir['vendor/plugins/*/test/functional/admin/*.rb']
      admin_controller_tests += Dir['test/functional/admin/*.rb']
      admin_controller_tests = admin_controller_tests.map { |i| File.basename(i) }

      # Generate unexisting controllers for resources which are not tied to
      # a model.
      self.resources.each do |resource|

        controller_filename = "#{resource.underscore}_controller.rb"
        controller_location = "#{admin_controllers_folder}/#{controller_filename}"

        if !admin_controllers.include?(controller_filename)
          controller = File.open(controller_location, "w+")
          content = <<-RAW
##
# Controller auto-generated by Typus.
# Use it to extend the admin functionality.
##
class Admin::#{resource}Controller < TypusController

  ##
  # This controller was generated because you have defined a resource 
  # which is not tied to a model on your `config/typus/XXXXXX_roles.yml` 
  # configuration file.
  #
  #     admin:
  #       #{resource}: index
  #

  def index
  end

end
          RAW

          controller.puts(content)
          controller.close
          puts "=> [typus] Admin::#{resource}Controller successfully created."

        end

        # And now we create the view.
        view_folder = "#{admin_views_folder}/#{resource.underscore}"
        view_filename = "index.html.erb"

        if !File.exists?("#{view_folder}/#{view_filename}")
          Dir.mkdir(view_folder) unless File.directory?(view_folder)
          view = File.open("#{view_folder}/#{view_filename}", "w+")
          content = <<-RAW

<!-- Sidebar -->

<% content_for :sidebar do %>
  <%= typus_block :location => 'dashboard', :partial => 'sidebar' %>
<% end %>

<!-- Content -->

<h2><%= link_to t("Dashboard"), admin_dashboard_url %> &rsaquo; #{resource.titleize}</h2>

<p>And here we do whatever we want to ...</p>

          RAW
          view.puts(content)
          view.close
          puts "=> [typus] app/views/admin/#{resource.underscore}/index.html.erb successfully created."
        end

      end

      models = self.models

      # Generate unexisting controllers for resources which are tied to a 
      # model.
      models.each do |model|

        # Controller app/controllers/admin/*
        controller_filename = "#{model.tableize}_controller.rb"
        controller_location = "#{admin_controllers_folder}/#{controller_filename}"

        if !admin_controllers.include?(controller_filename)
          controller = File.open(controller_location, "w+")

          content = <<-RAW
##
# Controller auto-generated by Typus.
# Use it to extend the admin functionality.
##
class Admin::#{model.pluralize}Controller < AdminController

=begin

  ##
  # You can overwrite any of the AdminController methods.
  #
  def index
  end

  ##
  # You can extend the AdminController with your actions.
  #
  # This actions have to be defined in `typus.yml`.
  #
  #   Post:
  #     actions:
  #       index: action_for_the_index
  #       edit: action_for_the_edit
  #
  def your_action
  end

=end

end

          RAW

          controller.puts(content)
          controller.close
          puts "[typus] Admin::#{model.pluralize}Controller successfully created."
        end

        # Helper app/helpers/admin/*
        helper_filename = "#{model.tableize}_helper.rb"
        helper_location = "#{admin_helpers_folder}/#{helper_filename}"

        if !admin_helpers.include?(helper_filename)
          helper = File.open(helper_location, "w+")

          content = <<-RAW
##
# Helper auto-generated by Typus.
# Use it to extend the admin functionality.
##
module Admin::#{model.pluralize}Helper

end
          RAW

          helper.puts(content)
          helper.close
          puts "[typus] Admin::#{model.pluralize}Helper successfully created."
        end

        # Test test/functional/admin/*_test.rb
        test_filename = "#{model.tableize}_controller_test.rb"
        test_location = "#{admin_controller_tests_folder}/#{test_filename}"

        if !admin_controller_tests.include?(test_filename)
          test = File.open(test_location, "w+")

          content = <<-RAW
##
# Test auto-generated by Typus.
# Use it to test the extended admin functionality.
##
require 'test_helper'

class Admin::#{model.pluralize}ControllerTest < ActionController::TestCase

  # Replace this with your real tests.
  test "the truth" do
    assert true
  end

end
          RAW

          test.puts(content)
          test.close
          puts "[typus] Admin::#{model.pluralize}ControllerTest successfully created."
        end

      end
    end

  end

end
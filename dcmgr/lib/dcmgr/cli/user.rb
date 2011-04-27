# -*- coding: utf-8 -*-

require 'sequel'
require 'yaml'

#TODO: Print only the first line of an exception?
module Dcmgr::Cli
  class UsersCli < Base
    namespace :user

    EMPTY_RECORD="<NULL>"

    no_tasks {
      def before_task
        # Setup DB connections and load paths for dcmgr_gui
        root_dir = File.expand_path('../../../', __FILE__)
        
        #get the database details
        #TODO:get this path in a less hard-coded way?
        content = File.new(File.expand_path('../../frontend/dcmgr_gui/config/database.yml', root_dir)).read
        settings = YAML::load content
        
        #load the database variables
        #TODO: get environment from RAILS_ENV
        db_environment = 'development'
        db_adapter = settings[db_environment]['adapter']
        db_host    = settings[db_environment]['host']
        db_name    = settings[db_environment]['database']
        db_user    = settings[db_environment]['user']
        db_pwd     = settings[db_environment]['password']
        
        #Connect to the database
        url = "#{db_adapter}://#{db_host}/#{db_name}?user=#{db_user}&password=#{db_pwd}"
        db = Sequel.connect(url)
        
        #load the cli environment
        $LOAD_PATH.unshift File.expand_path('../../frontend/dcmgr_gui/config', root_dir)
        $LOAD_PATH.unshift File.expand_path('../../frontend/dcmgr_gui/app/models', root_dir)
        
        require 'environment-cli'
        require 'user'
        require 'account'
        User.db = db
        Account.db = db
      end
    }
    
    desc "create", "Create a new user."
    method_option :name, :type => :string, :required => true, :aliases => "-n", :desc => "The name for the new user." #Maximum size: 200
    #method_option :uuid, :type => :string, :required => true, :aliases => "-u", :desc => "The uuid for the new user." #Maximum size: 8
    method_option :login_id, :type => :string, :aliases => "-l", :desc => "Optional: The login_id for the new user." #Maximum size: 255
    method_option :password, :type => :string, :required => true, :aliases => "-p", :desc => "The password for the new user." #Maximum size: 255
    method_option :primary_account_id, :type => :string, :aliases => "-a", :desc => "Optional: The primary account to associate this user with." #Maximum size: 255
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def create
      if options[:name].length > 200
        raise "User name can not be longer than 200 characters"
      elsif options[:login_id] != nil && options[:login_id].length > 255
        raise "User login_id can not be longer than 255 characters"
      elsif options[:password].length > 255
        raise "User password can not be longer than 255 characters"
      elsif options[:primary_account_id] != nil && options[:primary_account_id].length > 255
        raise "User primary_account_id can not be longer than 255 characters"
      else
        #Set values to be inserted
        pwd_hash = User.encrypt_password(options[:password])
        time = Time.new()
        now = Sequel.string_to_datetime "#{time.year}-#{time.month}-#{time.day} #{time.hour}:#{time.min}:#{time.sec}"
        #uuid = Account.uuid(options[:uuid])
        
        #Check if user exists
        #raise "A user with this uuid already exists." if User.get_user(uuid)
        
        #Check if the primary account uuid exists
        raise "Primary account id doesn't exit." if options[:primary_account_id] != nil && Account.filter(:uuid => options[:primary_account_id]).empty?
        
        #Put them in there
        new_user = User.create(
                               :name                => options[:name],
                               #:uuid                => uuid,
                               :created_at          => now,
                               :updated_at          => now,
                               :login_id            => options[:login_id],
                               :password            => pwd_hash,
                               :primary_account_id  => options[:primary_account_id]
                               )
        
        puts "New user created with id #{new_user.uuid}"# if options[:verbose]
        
        #Associate the new user with his primary account			
        new_user.add_account Account.find(:uuid => options[:primary_account_id]) unless options[:primary_account_id] == nil
      end
    end

    desc "describe", "Show all users currently in the database"
    method_option :id, :type => :string, :aliases => "-i", :desc => "The uuid for the account to show."
    method_option :times, :type => :boolean, :aliases => "-t", :desc => "Print the times when the user was created and last updated."
    method_option :associations, :type => :boolean, :aliases => "-a", :desc => "Print the account uuid(s) that the user is associated with."
    def describe
      #TODO: print this out prettier but still easy to use grep on

      header = "uuid | name | login id | primary account uuid"
      header += " | created at | last updated at" if options[:times]
      header += " | associated accounts" if options[:associations]

      puts header
      
      if options[:id] == nil
	users = User.all
      else
	users = User.filter(:uuid => options[:id]).all
      end
      
      users.each { |u|
        #prepare empty values
        name = EMPTY_RECORD
        uuid = EMPTY_RECORD
        login_id = EMPTY_RECORD
        primary_account_id = EMPTY_RECORD

        #set values that aren't empty
        name = u[:name] unless u[:name] == ""
        uuid = u[:uuid] unless u[:id] == nil
        login_id = u[:login_id] unless u[:login_id] == nil
        primary_account_id = u[:primary_account_id] unless u[:primary_account_id] == nil

        #Print it all
        print "#{uuid} | #{name} | #{login_id} | #{primary_account_id}"

        if options[:times]
          print " | #{u[:created_at]}"
          print " | #{u[:updated_at]}"
        end

        if options[:associations]
          associations = "" 
          u.accounts.each { |a|
            associations += "#{a[:uuid]}"
            associations += ", "
          }
          associations = associations[0,associations.length-2]
          associations = EMPTY_RECORD if associations == nil
          
          print " | #{associations}"
        end

        print "\n"
      }
    end

    desc "update", "Update an existing user."
    method_option :id, :type => :string, :required => true, :aliases => "-i", :desc => "The uuid of the user to be updated."
    method_option :name, :type => :string, :aliases => "-n", :desc => "The new name for the user." #Maximum size: 200
    method_option :uuid, :type => :string, :aliases => "-u", :desc => "The new uuid for the user." #Maximum size: 8
    method_option :login_id, :type => :string, :aliases => "-l", :desc => "The new login_id for the user." #Maximum size: 255
    method_option :password, :type => :string, :aliases => "-p", :desc => "The new password for the user." #Maximum size: 255
    method_option :primary_account_id, :type => :string, :aliases => "-a", :desc => "The new primary account to associate this user with."
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def update  
      if options[:name] != nil && options[:name].length > 200
        raise "User name can not be longer than 200 characters"
      elsif options[:login_id] != nil && options[:login_id].length > 255
        raise "User login_id can not be longer than 255 characters"
      elsif options[:password] != nil && options[:password].length > 255
        raise "User password can not be longer than 255 characters"
      elsif options[:primary_account_id] != nil && options[:primary_account_id].length > 255
        raise "User primary_account_id can not be longer than 255 characters"
        raise "No account exists with uuid #{options[:primary_account_id]}" if Account.filter(uuid => options[:primary_account_id]).empty?
      else
        time = Time.new()
        now = Sequel.string_to_datetime "#{time.year}-#{time.month}-#{time.day} #{time.hour}:#{time.min}:#{time.sec}"			
        to_be_updated = User.find(:uuid => options[:id])
        
        raise "A user with uuid #{options[:id]} doesn't exit" if to_be_updated == nil
        uuid = Account.uuid(options[:uuid]) unless options[:uuid] == nil
        unless options[:primary_account_id] == nil	
          auuid = Account.uuid(options[:primary_account_id])
          raise "No account exists with uuid #{auuid}" if Account.filter(:uuid => auuid).empty?
        end
        
        #this variables will be set in case any change to a user is made. Used to determine if update_at needs to be set.
        changed = false
        
        unless options[:uuid] == nil
          to_be_updated.uuid = uuid
          puts "User #{options[:id]}'s uuid changed to #{uuid}" if options[:verbose]
          changed = true
        end
        
        unless options[:name] == nil
          to_be_updated.name = options[:name]
          puts "User #{options[:id]}'s name changed to #{options[:name]}" if options[:verbose]
          changed = true
        end
        
        unless options[:login_id] == nil
          to_be_updated.login_id = options[:login_id]
          puts "User #{options[:id]}'s login id changed to #{options[:login_id]}" if options[:verbose]
          changed = true
        end
        
        unless options[:password] == nil
          to_be_updated.password = User.encrypt_password(options[:password])
          puts "User #{options[:id]}'s password changed" if options[:verbose]
          changed = true
        end		  
        
        unless options[:primary_account_id] == nil
          to_be_updated.primary_account_id = auuid
          puts "User #{options[:id]}'s primary account uuid changed to #{options[:primary_account_id]}" if options[:verbose]
          to_be_updated.add_account Account.find(:uuid => auuid)
          changed = true
        end
        
        if changed
          to_be_updated.updated_at = now
          to_be_updated.save
        else
          puts "Nothing to do." if options[:verbose]
        end
      end
    end

    #TODO: allow deletion of multiple id's at once
    desc "delete", "Delete an existing user."
    method_option :id, :type => :string, :required => true, :aliases => "-i"
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def delete
      to_delete = User.find(:uuid => options[:id])
      raise "No user exists with uuid #{options[:id]}." if to_delete == nil
      
      
      relations = to_delete.accounts
      for ss in 0...relations.length do
        puts "Deleting association with account #{relations[0].uuid}." if options[:verbose]
        to_delete.remove_account(relations[0])		  
      end
      
      #Delete user
      to_delete.destroy
      puts "User #{options[:id]} has been deleted." if options[:verbose]
    end
    
    desc "associate", "Associate a user with one or multiple accounts."
    method_option :id, :type => :string, :required => true, :aliases => "-i", :desc => "The uuid of the users to associate with the account."
    method_option :account_id, :type => :array, :required => true, :aliases => "-a", :desc => "The id of the acounts to associate these user with. Any non-existing or non numeral id will be ignored" 
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def associate
      uid = Account.uuid(options[:id])
      aid = options[:account_id]
      
      raise "A user with uuid #{uid} doesn't exist." if User.find(:uuid => uid) == nil
      
      user = User.find(:uuid => uid)
      aid.each { |a|
	#TODO: check uuid syntax?
        a_uuid = a #Account.uuid(a)
        if Account.find(:uuid => a_uuid) == nil
          puts "An account with id #{a} doesn't exist."
        elsif user.accounts.index(Account.find(:uuid => a_uuid)) != nil
          puts "User #{uid} is already associated with account #{a}." if options[:verbose]
        else
          user.add_account(Account.find(:uuid => a_uuid))
          
          puts "User #{uid} successfully associated with account #{a}." if options[:verbose]
        end
      }
    end
    
    desc "dissociate", "Dissociate a user from one or multiple accounts."
    method_option :id, :string => :numeric, :required => true, :aliases => "-i", :desc => "The id of the users to dissociate from the account."
    method_option :account_id, :type => :array, :required => true, :aliases => "-a", :desc => "The id of the acounts to dissociate these user from. Any non-existing or non numeral id will be ignored" 
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def dissociate
      uid = Account.uuid(options[:id])
      aid = options[:account_id]
      
      raise "A user with uuid #{uid} doesn't exist." if User.find(:uuid => uid) == nil
      
      user = User.find(:uuid => uid)
      aid.each { |a|
        #TODO: check uuid syntax?
        a_uuid = a #Account.uuid(a)
        if Account.filter(:uuid => a).empty?
          puts "An account with uuid #{a} doesn't exist."
        elsif user.accounts.index(Account.find(:uuid => a_uuid)) == nil
          puts "User #{uid} is not associated with account #{a}." if options[:verbose]
        else
          user.remove_account(Account.find(:uuid => a_uuid))
          
          puts "User #{uid} successfully dissociated from account #{a}." if options[:verbose]
          
          if a_uuid == user.primary_account_id
            user.primary_account_id = nil
            user.save
            puts "  This was user #{uid}'s primary account. Has been set to Null now." if options[:verbose]
          end
        end
      }
    end
    
  end
end

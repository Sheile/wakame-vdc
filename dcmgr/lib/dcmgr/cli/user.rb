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
    
    desc "add [options]", "Create a new user."
    method_option :name, :type => :string, :required => true, :aliases => "-n", :desc => "The name for the new user." #Maximum size: 200
    method_option :login_id, :type => :string, :aliases => "-l", :desc => "Optional: The login_id for the new user." #Maximum size: 255
    method_option :password, :type => :string, :required => true, :aliases => "-p", :desc => "The password for the new user." #Maximum size: 255
    method_option :primary_account_id, :type => :string, :aliases => "-a", :desc => "Optional: The primary account to associate this user with." #Maximum size: 255
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def add
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
        
        #Check if the primary account uuid exists
        raise "Primary account id doesn't exit." if options[:primary_account_id] != nil && Account.filter(:uuid => options[:primary_account_id]).empty?
        
        #Put them in there
        new_user = User.create(
                               :name                => options[:name],                               
                               :created_at          => now,
                               :updated_at          => now,
                               :login_id            => options[:login_id],
                               :password            => pwd_hash,
                               :primary_account_id  => options[:primary_account_id]
                               )
        
        puts new_user.canonical_uuid# if options[:verbose]
        
        #Associate the new user with his primary account			
        new_user.add_account Account.find(:uuid => options[:primary_account_id]) unless options[:primary_account_id] == nil
      end
    end

    desc "show [UUID] [options]", "Show one user or all users currently in the database"        
    def show(uuid = nil)
      if uuid        
        user = User[uuid] || raise(Thor::Error, "Unknown User UUID: #{uuid}")
        puts ERB.new(<<__END, nil, '-').result(binding)
User UUID: <%= user.canonical_uuid %>
Name:
  <%= user.name %>
<%- if user.login_id -%>
Login ID:
  <%= user.login_id %>
<%- end -%>
<%- if user.primary_account_id -%>
Primary Account:
<%- prim_acc = Account.find(:uuid => user.primary_account_id) -%>
  <%= prim_acc.canonical_uuid %>\t<%= prim_acc.name %>
<%- end -%>
<%- unless user.accounts.empty? -%>
Associated accounts:
<%- user.accounts.each { |row| -%>
  <%= row.canonical_uuid %>\t<%= row.name %>
<%- } -%>
<%- end -%>
__END
      else	
        user = User.all
        puts ERB.new(<<__END, nil, '-').result(binding)
<%- user.each { |row| -%>
<%= row.canonical_uuid %>\t<%= row.name %>
<%- } -%>
__END
      end
    end    

    desc "modify UUID [options]", "Update an existing user."    
    method_option :name, :type => :string, :aliases => "-n", :desc => "The new name for the user." #Maximum size: 200    
    method_option :login_id, :type => :string, :aliases => "-l", :desc => "The new login_id for the user." #Maximum size: 255
    method_option :password, :type => :string, :aliases => "-p", :desc => "The new password for the user." #Maximum size: 255
    method_option :primary_account_id, :type => :string, :aliases => "-a", :desc => "The new primary account to associate this user with."
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def modify(uuid)
      if options[:name] != nil && options[:name].length > 200
        raise "User name can not be longer than 200 characters"
      elsif options[:login_id] != nil && options[:login_id].length > 255
        raise "User login_id can not be longer than 255 characters"
      elsif options[:password] != nil && options[:password].length > 255
        raise "User password can not be longer than 255 characters"
      elsif options[:primary_account_id] != nil && options[:primary_account_id].length > 255
        raise "User primary_account_id can not be longer than 255 characters"
      else
        time = Time.new()
        now = Sequel.string_to_datetime "#{time.year}-#{time.month}-#{time.day} #{time.hour}:#{time.min}:#{time.sec}"			
        to_be_updated = User[uuid] || raise(Thor::Error, "Unknown User UUID: #{uuid}")
                
        uuid = Account.uuid(options[:uuid]) unless options[:uuid] == nil
        unless options[:primary_account_id] == nil
          auuid = options[:primary_account_id]
          raise(Thor::Error, "Unknown Account UUID #{auuid}") if Account[auuid].nil?
        end
        
        #this variables will be set in case any change to a user is made. Used to determine if update_at needs to be set.
        changed = false
        
        unless options[:name] == nil
          to_be_updated.name = options[:name]
          puts "User #{uuid}'s name changed to #{options[:name]}" if options[:verbose]
          changed = true
        end
        
        unless options[:login_id] == nil
          to_be_updated.login_id = options[:login_id]
          puts "User #{uuid}'s login id changed to #{options[:login_id]}" if options[:verbose]
          changed = true
        end
        
        unless options[:password] == nil
          to_be_updated.password = User.encrypt_password(options[:password])
          puts "User #{uuid}'s password changed" if options[:verbose]
          changed = true
        end		  
        
        unless options[:primary_account_id] == nil
          acc = Account[auuid]
          to_be_updated.primary_account_id = acc.uuid
          puts "User #{uuid}'s primary account uuid changed to #{auuid}" if options[:verbose]   
          to_be_updated.add_account(acc) unless to_be_updated.accounts.include? acc
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
    desc "del UUID", "Delete an existing user."    
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def del(uuid)
      to_delete = User[uuid] || raise(Thor::Error, "Unknown User UUID: #{uuid}")
      
      relations = to_delete.accounts
      for ss in 0...relations.length do
        puts "Deleting association with account #{relations[0].canonical_uuid}." if options[:verbose]
        to_delete.remove_account(relations[0])		  
      end
      
      #Delete user
      to_delete.destroy
      puts "User #{uuid} has been deleted." if options[:verbose]
    end
    
    desc "associate UUID", "Associate a user with one or multiple accounts."
    method_option :account_ids, :type => :array, :required => true, :aliases => "-a", :desc => "The id of the acounts to associate these user with. Any non-existing or non numeral id will be ignored" 
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def associate(uuid)      
      user = User[uuid] || raise(Thor::Error, "Unknown User UUID: #{uuid}")
      options[:account_ids].each { |a|
        if Account[a].nil?
          puts "Unknown Account UUID: #{a}" if options[:verbose]
        elsif !user.accounts.index(Account[a]).nil?#user.accounts[a] != nil
          puts "User #{uuid} is already associated with account #{a}." if options[:verbose]
        else
          user.add_account(Account[a])
          
          puts "User #{uid} successfully associated with account #{a}." if options[:verbose]
        end
      }
    end
    
    desc "dissociate UUID", "Dissociate a user from one or multiple accounts."    
    method_option :account_ids, :type => :array, :required => true, :aliases => "-a", :desc => "The id of the acounts to dissociate these user from. Any non-existing or non numeral id will be ignored" 
    method_option :verbose, :type => :boolean, :aliases => "-v", :desc => "Print feedback on what is happening."
    def dissociate(uuid)
      user = User[uuid] || raise(Thor::Error, "Unknown User UUID: #{uuid}")
      options[:account_ids].each { |a|
        if Account[a].nil?
          puts "Unknown Account UUID: #{a}" if options[:verbose]
        elsif user.accounts.index(Account[a]).nil?
          puts "User #{uuid} is not associated with account #{a}." if options[:verbose]
        else
          user.remove_account(Account[a])
          
          puts "User #{uuid} successfully dissociated from account #{a}." if options[:verbose]
          
          if Account[a].uuid == user.primary_account_id
            user.primary_account_id = nil
            user.save
            puts "This was user #{uuid}'s primary account. Has been set to Null now." if options[:verbose]
          end
        end
      }
    end
    
  end
end

# -*- coding: utf-8 -*-

module Dcmgr::Cli
  class Image < Base
    namespace :image
    C = Dcmgr::Constants
    M = Dcmgr::Models

    ARCHES = C::HostNode::SUPPORTED_ARCH
    STATES = C::Image::STATES
    OS_TYPES = C::Image::OS_TYPES

    class AddOperation < Base
      namespace :add

      no_tasks do
        def self.service_types
          Dcmgr::Configurations.dcmgr.service_types.keys.sort
        end

        def self.add_shared_options
          option :uuid, type: :string, desc: "The UUID for the new machine image"
          option :account_id, type: :string, required: true,
            desc: "The UUID of the account that this machine image belongs to"
          option :arch, type: :string, default: 'x86_64',
            desc: "The architecture for the new machine image. [#{ARCHES.join(', ')}]"
          option :is_public, type: :boolean, default: false,
            desc: "A flag that determines whether the new machine image is public or not"
          option :description, type: :string,
            desc: "An arbitrary description of the new machine image"
          option :file_format, type: :string, default: "raw",
            desc: "The file format for the new machine image"
          option :root_device, type: :string,
            desc: "The root device of image"
          option :state, type: :string, default: "available",
            desc: "The state for the new machine image"
          option :service_type, type: :string, :default=>Dcmgr::Configurations.dcmgr.default_service_type,
            desc: "Service type of the machine image. (#{service_types.join(', ')})"
          option :display_name, type: :string, required: true,
            desc: "Display name of the machine image"
          option :instance_model_name, type: :string,
            desc: "The model name of the new instance"
          option :parent_image_id, type: :string,
            desc: "The parent image UUID"
          option :os_type, type: :string, default: C::Image::OS_TYPE_LINUX,
            desc: "The type of OS installed in this image. (#{OS_TYPES.join(', ')})"
        end

        def argument_checks(backup_object_id, options)
          UnsupportedArchError.raise(options[:arch]) unless ARCHES.member?(options[:arch])
          UnknownUUIDError.raise(backup_object_id) unless M::BackupObject[backup_object_id]

          unless OS_TYPES.member?(options[:os_type])
            InvalidOSTypeError.raise(options[:os_type])
          end

          unless STATES.member?(options[:state])
            InvalidStateError.raise(options[:state])
          end
        end
      end

      desc "local backup_object_id [options]", "Register local store machine image"
      add_shared_options
      option :is_cacheable, type: :boolean, default: false,
        desc:"A flag that determines whether the new machine image is cacheable or not"
      def local(backup_object_id)
        argument_checks(backup_object_id, options)

        fields = options.dup
        fields[:backup_object_id] = backup_object_id
        fields[:boot_dev_type] = C::Image::BOOT_DEV_LOCAL

        puts add(M::Image, fields)
      end

      desc "volume backup_object_id [options]", "Register volume store machine image."
      add_shared_options
      def volume(backup_object_id)
        argument_checks(backup_object_id, options)

        fields = options.dup
        fields[:backup_object_id] = backup_object_id
        fields[:boot_dev_type] = C::Image::BOOT_DEV_SAN

        puts add(M::Image, fields)
      end

      protected
      def self.basename
        "vdc-manage #{Image.namespace} #{self.namespace}"
      end
    end

    register AddOperation, 'add', "add IMAGE_TYPE [options]", "Add image metadata [#{AddOperation.tasks.keys.join(', ')}]"

    desc "modify UUID [options]", "Modify a registered machine image"
    method_option :description, :type => :string, :desc => "An arbitrary description of the machine image"
    method_option :state, :type => :string, :desc => "The state for the machine image"
    method_option :account_id, :type => :string, :desc => "The UUID of the account that this machine image belongs to."
    method_option :arch, :type => :string, :desc => "The architecture for the new machine image. [#{C::HostNode::SUPPORTED_ARCH.join(', ')}]"
    method_option :is_public, :type => :boolean,  :desc => "A flag that determines whether the new machine image is public or not."
    method_option :description, :type => :string, :desc => "An arbitrary description of the new machine image"
    method_option :file_format, :type => :string, :desc => "The file format for the new machine image"
    method_option :root_device, :type => :string, :desc => "The root device of image"
    method_option :service_type, :type => :string, :desc => "Service type of the machine image. (#{Dcmgr::Configurations.dcmgr.service_types.keys.sort.join(', ')})"
    method_option :display_name, :type => :string, :desc => "Display name of the machine image"
    method_option :backup_object_id, :type => :string, :desc => "Backup object for the machine image"
    method_option :is_cacheable, :type => :boolean, :desc =>"A flag that determines whether the new machine image is cacheable or not"
    method_option :instance_model_name, :type => :string, :desc => "The model name of the new instance"
    method_option :parent_image_id, :type => :string, :desc => "The parent image UUID"
    method_option :os_type, type: :string, default: C::Image::OS_TYPE_LINUX,
      desc: "The type of OS installed in this image. (#{OS_TYPES.join(', ')})"
    def modify(uuid)
      UnknownUUIDError.raise(uuid) if M::Image[uuid].nil?
      UnsupportedArchError.raise(options[:arch]) if options[:arch] && !ARCHES.member?(options[:arch])

      fields = options.dup

      super(M::Image,uuid,fields)
    end

    desc "del IMAGE_ID", "Delete registered machine image"
    def del(image_id)
      UnknownUUIDError.raise(image_id) if M::Image[image_id].nil?
      super(M::Image, image_id)
    end

    desc "show [IMAGE_ID]", "Show list of machine image and details"
    def show(uuid=nil)
      if uuid
        img = M::Image[uuid] || UnknownUUIDError.raise(uuid)
        print ERB.new(<<__END, nil, '-').result(binding)
UUID: <%= img.canonical_uuid %>
Name: <%= img.display_name %>
Account ID: <%= img.account_id %>
Boot Type: <%= img.boot_dev_type == C::Image::BOOT_DEV_LOCAL ? 'local' : 'volume'%>
Arch: <%= img.arch %>
Is Public: <%= img.is_public %>
State: <%= img.state %>
Service Type: <%= img.service_type %>
Cacheable: <%= img.is_cacheable %>
OS Type: <%= img.os_type %>
Parent Image ID: <%= img.parent_image_id %>
Create: <%= img.created_at %>
Update: <%= img.updated_at %>
Delete: <%= img.deleted_at %>
Features:
<%= img.features %>
<%- if img.description -%>
Description:
  <%= img.description %>
<%- end -%>
<%- if img.instance_model_name -%>
Instance Model Name: <%= img.instance_model_name %>
<%- end -%>
__END
      else
        ds = M::Image.dataset
        table = [['UUID', 'Account ID', 'Service Type', 'Name', 'Boot Type', 'Arch']]
        ds.each { |r|
          table << [r.canonical_uuid, r.account_id, r.service_type, r.display_name, (r.boot_dev_type == C::Image::BOOT_DEV_LOCAL ? 'local' : 'volume'), r.arch]
        }

        shell.print_table(table)
      end
    end

    desc "features IMAGE_ID", "Set features attribute to the image"
    method_option :virtio, :type => :boolean, :desc => "Virtio ready image."
    method_option :acpi, :type => :boolean, :desc => "ACPI support enabled."
    def features(uuid)
      img = M::Image[uuid] || UnknownUUIDError.raise(uuid)

      if options[:virtio]
        img.set_feature(:virtio, options[:virtio])
      end
      if options[:acpi]
        img.set_feature(:acpi, options[:acpi])
      end

      img.save_changes
    end

  end
end

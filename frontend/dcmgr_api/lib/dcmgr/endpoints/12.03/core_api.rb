# -*- coding: utf-8 -*-

require 'time'

require 'sinatra/base'
require 'sinatra/dcmgr_api_setup'

require 'dcmgr/endpoints/errors'

module Dcmgr::Endpoints::V1203
  class CoreAPI < Sinatra::Base
    # include Dcmgr::Logger
    register Sinatra::DcmgrAPISetup

    # To access constants in this namespace
    include Dcmgr::Endpoints

    E = Dcmgr::Endpoints::Errors
    R = Dcmgr::Endpoints::V1203::Responses

    include Dcmgr::Endpoints::Helpers

    helpers do
      #
      #  - start
      #  - limit
      #  - sort_by
      def paging_params_filter(ds)

        total = ds.count
        
        start = if params[:start]
                  if params[:start] =~ /^\d+$/
                    params[:start].to_i
                  else
                    raise E::InvalidParameter, :start
                  end
                else
                  0
                end
        limit = if params[:limit]
                  if params[:limit] =~ /^\d+$/
                  params[:limit].to_i
                  else
                    raise E::InvalidParameter, :limit
                  end
                else
                  0
                end
        limit = limit < 1 ? 250 : limit
        
        ds = if params[:sort_by]
               params[:sort_by] =~ /^(\w+)(\.desc|\.asc)?$/
               ds.order(params[:sort_by])
             else
               ds.order(:id.desc)
             end

        ds = ds.limit(limit, start)
        [ds, total, start, limit]
      end

      # #{param}_since and #{param}_until
      def datetime_range_params_filter(param, ds)
        since_time = until_time = nil
        since_key = "#{param}_since"
        until_key = "#{param}_until"
        if params[since_key]
          since_time = begin
                         Time.iso8601(params[since_key].to_s).utc
                       rescue ArgumentError
                         raise E::InvalidParameter, since_key
                       end
        end
        if params[until_key]
          until_time = begin
                         Time.iso8601(params[until_key].to_s).utc
                       rescue ArgumentError
                         raise E::InvalidParameter, until_key
                       end
        end
        
        ds = if since_time && until_time
               if !(since_time < until_time)
                 raise E::InvalidParameter, "#{since_key} is larger than #{until_key}"
               end
               ds.filter("#{param}_at >= ?", since_time).filter("#{param}_at <= ?", until_time)
             elsif since_time
               ds.filter("#{param}_at >= ?", since_time)
             elsif until_time
               ds.filter("#{param}_at <= ?", until_time)
             else
               ds
             end
        ds
      end
      
      def collection_respond_with(ds, &blk)
        ds, total, start, limit  = paging_params_filter(ds)
        
        respond_with([{
                        :total => total,
                        :start => start,
                        :limit => limit,
                        :results=> blk.call(ds)
                      }])
      end
    end
    
    # default output format.
    respond_to :json, :yml

    # load_namespace('instances')
    # load_namespace('images')
    # load_namespace('host_nodes')
    # load_namespace('volumes')
    # load_namespace('volume_snapshots')
    # load_namespace('security_groups')
    # load_namespace('storage_nodes')
    # load_namespace('ssh_key_pairs')
    load_namespace('networks')
    # load_namespace('network_vifs')
    # load_namespace('dc_networks')
    # load_namespace('reports')
    # load_namespace('load_balancers')
    # load_namespace('backup_storages')
    # load_namespace('backup_objects')
    # load_namespace('host_node_groups')
    # load_namespace('storage_node_groups')
    # load_namespace('network_groups')
    # load_namespace('accounts')
  end
end
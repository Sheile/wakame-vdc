# -*- coding: utf-8 -*-

module Dcmgr::Rpc
  class WindowsHandler < EndpointBuilder

    include HvaHandler::Helpers

    concurrency Dcmgr.conf.windows.thread_concurrency.to_i
    job_thread_pool Isono::ThreadPool.new(Dcmgr.conf.windows.thread_concurrency.to_i,
                                          "WindowsHandle")

    job :launch_windows, proc {
      @hva_ctx = HvaContext.new(self)
      @inst = request.args[0]
      @inst_id = @inst[:uuid]

      encrypted_password = task_session.invoke(
        @hva_ctx.hypervisor_driver_class,
        :get_windows_password_hash,
        [@hva_ctx]
      )

      rpc.request(
        'hva-collector',
        'update_instance',
        @inst_id,
        {encrypted_password: encrypted_password}
      )

      update_instance_state({:state=>:running}, ['hva/instance_started'])
    }, proc { failed_instance_launch_rollback }

  end
end

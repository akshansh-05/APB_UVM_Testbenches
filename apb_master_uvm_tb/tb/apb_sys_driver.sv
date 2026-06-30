class apb_sys_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_sys_driver)
  virtual apb_if vif;

  function new(string name = "apb_sys_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SYS_DRV", "Could not get virtual interface 'vif'")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item req;

    // Wait out reset, then park all signals in a known idle state
    wait (vif.PRESETn === 1'b1);
    vif.master_cb.transfer        <= 1'b0;
    vif.master_cb.READ_WRITE      <= 1'b0;
    vif.master_cb.apb_read_paddr  <= '0;
    vif.master_cb.apb_write_paddr <= '0;
    vif.master_cb.apb_write_data  <= '0;
    @(vif.master_cb);

    forever begin
      seq_item_port.get_next_item(req);

      // 1. Assert the request
      vif.master_cb.transfer   <= 1'b1;
      vif.master_cb.READ_WRITE <= req.read;
      if (req.read)
        vif.master_cb.apb_read_paddr  <= req.addr;
      else begin
        vif.master_cb.apb_write_paddr <= req.addr;
        vif.master_cb.apb_write_data  <= req.wdata;
      end

      // 2. Hold transfer HIGH until the access actually completes.
      //    Complete = in ACCESS phase (PSEL & PENABLE) and slave ready (PREADY).
      //    This automatically handles 0, 1, or many wait states.
      @(vif.master_cb);
      while (!((vif.master_cb.PSEL1 | vif.master_cb.PSEL2)
               && vif.master_cb.PENABLE
               && vif.master_cb.PREADY))
        @(vif.master_cb);

      // 3. Access done -> drop the request
      vif.master_cb.transfer <= 1'b0;

      seq_item_port.item_done();
    end
  endtask

endclass
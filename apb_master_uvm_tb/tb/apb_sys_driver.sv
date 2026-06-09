class apb_sys_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_sys_driver)                   // Factory registration macro for UVM components

  virtual apb_if vif;

  function new(string name = "apb_sys_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    @(vif.master_cb);

    vif.master_cb.transfer        <= 0;
    vif.master_cb.READ_WRITE      <= 0;
    vif.master_cb.apb_write_paddr <= 0;
    vif.master_cb.apb_read_paddr  <= 0;
    vif.master_cb.apb_write_data  <= 0;

    forever begin
      apb_seq_item item;
      int timeout_cnt;                                   // Timeout counter to detect hung simulation

      seq_item_port.get_next_item(item);

      `uvm_info("DRV", $sformatf("Driving: addr=0x%03h wdata=0x%02h read=%0b", item.addr, item.wdata, item.read), UVM_MEDIUM)

      // Initiate transaction on the interface and wait for the slave to complete the handshake via PREADY
      vif.master_cb.transfer   <= 1;
      vif.master_cb.READ_WRITE <= item.read;
      if (item.read) begin
        vif.master_cb.apb_read_paddr <= item.addr;
      end
      else begin
        vif.master_cb.apb_write_paddr <= item.addr;
        vif.master_cb.apb_write_data  <= item.wdata;
      end

      timeout_cnt = 0;
      do begin
        @(vif.master_cb);
        timeout_cnt++;
        if (timeout_cnt > 20) begin                      // Safety limit of 20 clock cycles exceeded
          `uvm_error("DRV", "Timeout waiting for PREADY!")
          break;
        end
      end while (!vif.master_cb.PREADY);                 // Loop finishes when PREADY goes high (handshake complete)

      if (item.read)
        item.rdata = vif.master_cb.apb_read_data_out;
      item.pslverr = vif.master_cb.PSLVERR;

      vif.master_cb.transfer <= 0;
      @(vif.master_cb);

      seq_item_port.item_done();
    end
  endtask

endclass

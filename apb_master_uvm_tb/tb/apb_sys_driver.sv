class sys_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(sys_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SYS_DRV", "Virtual interface not set for sys_driver")
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();

    forever begin
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask

  // Park all system outputs in a known-idle state
  task reset_signals();
    vif.master_cb.transfer         <= 1'b0;
    vif.master_cb.READ_WRITE       <= 1'b0;
    vif.master_cb.apb_write_paddr  <= '0;
    vif.master_cb.apb_read_paddr   <= '0;
    vif.master_cb.apb_write_data   <= '0;
  endtask

  // Drive one system-level transaction, synchronous to master_cb
  task drive_transfer(apb_seq_item tr);
    @(vif.master_cb);

    // Present request on the driving edge
    vif.master_cb.transfer        <= 1'b1;
    vif.master_cb.READ_WRITE      <= tr.READ_WRITE;   // 1 = read, 0 = write
    vif.master_cb.apb_read_paddr  <= tr.apb_read_paddr;
    vif.master_cb.apb_write_paddr <= tr.apb_write_paddr;
    vif.master_cb.apb_write_data  <= tr.apb_write_data;

    `uvm_info("SYS_DRV",
      $sformatf("Driving %s | waddr=0x%0h raddr=0x%0h wdata=0x%0h",
                tr.READ_WRITE ? "READ" : "WRITE",
                tr.apb_write_paddr, tr.apb_read_paddr, tr.apb_write_data),
      UVM_MEDIUM)

    // Wait synchronously for APB completion: PENABLE && PREADY
    do @(vif.master_cb);
    while (!(vif.master_cb.PENABLE === 1'b1 && vif.master_cb.PREADY === 1'b1));

    // Access completed -> release request for next cycle
    vif.master_cb.transfer <= 1'b0;

    `uvm_info("SYS_DRV", "Transfer accepted by APB side (PENABLE & PREADY)", UVM_HIGH)
  endtask

endclass